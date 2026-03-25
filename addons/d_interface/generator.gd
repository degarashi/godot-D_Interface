extends Object


## @brief .ifc ファイルの内容からブリッジ用GDScriptを生成する
static func generate_from_ifc(source_text: String, class_hint: String = "") -> String:
	# 解析フェーズ
	var parent_info := _extract_parent_info(source_text)
	var my_defs := _parse_single_ifc(source_text)

	var lines: Array[String] = []

	# --- 警告ヘッダーの挿入 ---
	lines.append("# " + "=".repeat(60))
	lines.append("#  WARNING: AUTO-GENERATED FILE. DO NOT EDIT MANUALLY.")
	lines.append("#  This file was generated from an .ifc definition.")
	lines.append("# " + "=".repeat(60))
	lines.append("")

	# 生成情報の追加
	var current_time := Time.get_datetime_string_from_system().replace("T", " ")
	lines.append("# Generated at: {0}".format([current_time]))
	lines.append("")

	# class_name の生成 (i_mover -> IMover)
	if not class_hint.is_empty():
		lines.append("class_name {0}".format([_format_class_name(class_hint)]))

	# --- 継承先の決定 ---
	# 親がいればそのインターフェースクラス名、いなければ InterfaceBase
	if not parent_info.class_name.is_empty():
		lines.append("extends {0}\n".format([parent_info.class_name]))
	else:
		lines.append("extends InterfaceBase\n")

	# 変数（プロパティ）の書き出し
	for var_name in my_defs.vars:
		var type = my_defs.vars[var_name]
		lines.append("# Prop: {0}".format([var_name]))
		lines.append("var {0}: {1}:".format([var_name, type]))
		lines.append("	set(v): _impl.{0} = v".format([var_name]))
		lines.append("	get: return _impl.{0}".format([var_name]))
		lines.append("")

	# メソッドの書き出し
	for func_name in my_defs.funcs:
		var data = my_defs.funcs[func_name]
		lines.append("func {0}({1}) -> {2}:".format([func_name, data.args, data.ret]))
		lines.append("	return _impl.{0}({1})".format([func_name, _extract_arg_names(data.args)]))
		lines.append("")

	return "\n".join(lines)


## @brief extends 行から親のパスとクラス名を抽出する
static func _extract_parent_info(text: String) -> Dictionary:
	var info: Dictionary[String, String] = {"path": "", "class_name": ""}
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("extends"):
			var parts := line.split('"')
			if parts.size() >= 2:
				var raw_path := parts[1]
				info.path = raw_path

				# --- 物理ファイルの存在チェック ---
				if raw_path.begins_with("res://"):
					if not FileAccess.file_exists(raw_path):
						push_error("[Interface] Parent file not found at: %s" % raw_path)
						# エラーは出すが、名前推測だけは続けて「型」としての体裁は保つ

				var file_name := raw_path.get_file().get_basename()
				info.class_name = _format_class_name(file_name)
			break
	return info


## @brief global_class (project.godotに登録されたもの) に存在するか確認
static func _is_global_script_exists(cls: String) -> bool:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == cls:
			return true
	return false


## @brief その .ifc ファイル自身の定義のみを解析する
static func _parse_single_ifc(source_text: String) -> Dictionary[String, Dictionary]:
	var defs: Dictionary[String, Dictionary] = {"funcs": {}, "vars": {}}

	var re_func := RegEx.new()
	re_func.compile("func\\s+(?<name>\\w+)\\s*\\((?<args>.*)\\)\\s*(->\\s*(?<ret>[\\w.]+))?")

	var re_var := RegEx.new()
	re_var.compile("var\\s+(?<name>\\w+)\\s*:\\s*(?<type>[\\w.]+)")

	for raw_line in source_text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#") or line.begins_with("extends"):
			continue

		var m_func := re_func.search(line)
		if m_func:
			var ret := m_func.get_string("ret")
			defs.funcs[m_func.get_string("name")] = {
				"args": m_func.get_string("args"), "ret": ret if not ret.is_empty() else "void"
			}
			continue

		var m_var := re_var.search(line)
		if m_var:
			defs.vars[m_var.get_string("name")] = m_var.get_string("type")

	return defs


## @brief ファイル名からインターフェースクラス名を生成 (i_pilot -> IPilot)
static func _format_class_name(raw: String) -> String:
	var clean := raw.trim_prefix("i_").capitalize().replace(" ", "")
	return "I" + clean


## @brief 引数文字列から名前だけを抽出
static func _extract_arg_names(args_str: String) -> String:
	if args_str.strip_edges().is_empty():
		return ""
	var names: Array[String] = []
	for part in args_str.split(","):
		var kv := part.split(":")
		names.append(kv[0].strip_edges())
	return ", ".join(names)
