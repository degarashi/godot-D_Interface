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
	var class_name_str := _format_class_name(class_hint)
	if not class_hint.is_empty():
		lines.append("class_name {0}".format([class_name_str]))

	# --- 継承先の決定 ---
	# 親がいればそのインターフェースクラス名、いなければ InterfaceBase
	if not parent_info.class_name.is_empty():
		lines.append("extends {0}\n".format([parent_info.class_name]))
	else:
		lines.append("extends InterfaceBase\n")

	# Enumの書き出し
	for enum_name: String in my_defs.enums:
		var values: String = my_defs.enums[enum_name]
		lines.append("enum {0} { {1} }".format([enum_name, values]))

	if not my_defs.enums.is_empty():
		lines.append("")

	# シグナルの宣言
	for sig_name: String in my_defs.signals:
		var data: Dictionary = my_defs.signals[sig_name]
		_append_comments(lines, data)
		lines.append("signal {0}({1})".format([sig_name, data.args]))

	if not my_defs.signals.is_empty():
		lines.append("")

	# 変数（プロパティ）の書き出し
	for var_name in my_defs.vars:
		var data: Dictionary = my_defs.vars[var_name]
		_append_comments(lines, data)
		lines.append("var {0}: {1}:".format([var_name, data.type]))
		lines.append("	set(v): _impl.{0} = v".format([var_name]))
		lines.append("	get: return _impl.{0}".format([var_name]))
		lines.append("")

	# メソッドの書き出し
	for func_name in my_defs.funcs:
		var data = my_defs.funcs[func_name]
		_append_comments(lines, data)
		lines.append("func {0}({1}) -> {2}:".format([func_name, data.args, data.ret]))

		# 戻り値が void かどうかで return の有無を切り替える
		if data.ret == "void":
			lines.append("	_impl.{0}({1})".format([func_name, _extract_arg_names(data.args)]))
		else:
			lines.append(
				"	return _impl.{0}({1})".format([func_name, _extract_arg_names(data.args)])
			)
		lines.append("")

	# --- 補助関数の追加 ---
	lines.append("static func cast(obj: Object) -> {0}:".format([class_name_str]))
	lines.append("	return Interface.as_interface(obj, {0}) as {0}".format([class_name_str]))
	lines.append("")

	lines.append("static func cast_checked(obj: Object) -> {0}:".format([class_name_str]))
	lines.append("	var res := cast(obj)")
	lines.append(
		'	assert(res != null, "[Interface] Cast failed: Object does not implement {0}")'.format(
			[class_name_str]
		)
	)
	lines.append("	return res")
	lines.append("")
	return "\n".join(lines)


## @brief 溜めていたコメント行を書き出す
static func _append_comments(lines: Array[String], data: Dictionary) -> void:
	if data.has("comment"):
		for c in data.comment:
			lines.append(c)


## @brief extends 行から親のパスとクラス名を抽出する
static func _extract_parent_info(text: String) -> Dictionary[String, String]:
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


## @brief その .ifc ファイル自身の定義のみを解析する
static func _parse_single_ifc(source_text: String) -> Dictionary[String, Dictionary]:
	var defs: Dictionary[String, Dictionary] = {"funcs": {}, "vars": {}, "signals": {}, "enums": {}}
	var comment_buffer: Array[String] = []

	# 複数行Enumの解析
	var re_enum_block := RegEx.new()
	re_enum_block.compile("enum\\s+(?<name>\\w+)\\s*\\{(?<values>[^}]*)\\}")
	var enum_matches := re_enum_block.search_all(source_text)
	for m: RegExMatch in enum_matches:
		var name := m.get_string("name")
		var values := m.get_string("values").strip_edges().replace("\n", " ")
		defs.enums[name] = values

	var re_func := RegEx.new()
	re_func.compile("func\\s+(?<name>\\w+)\\s*\\((?<args>.*)\\)\\s*(->\\s*(?<ret>[\\w.]+))?")

	var re_var := RegEx.new()
	re_var.compile("var\\s+(?<name>\\w+)\\s*:\\s*(?<type>[\\w.]+)")

	var re_sig := RegEx.new()
	re_sig.compile("signal\\s+(?<name>\\w+)\\s*(\\((?<args>.*)\\))?")

	# Enum以外の定義を行単位で解析
	for raw_line: String in source_text.split("\n"):
		var line := raw_line.strip_edges()

		# ドキュメントコメントの収集
		if line.begins_with("##"):
			comment_buffer.append(line)
			continue

		# 定義に直結しない行（空行や通常コメント）があればバッファを捨てる
		if line.is_empty() or (line.begins_with("#") and not line.begins_with("##")):
			comment_buffer.clear()
			continue

		# Signal
		var m_sig := re_sig.search(line)
		if m_sig:
			defs.signals[m_sig.get_string("name")] = {
				"args": m_sig.get_string("args"), "comment": comment_buffer.duplicate()
			}
			comment_buffer.clear()
			continue

		# Function
		var m_func := re_func.search(line)
		if m_func:
			var ret := m_func.get_string("ret")
			defs.funcs[m_func.get_string("name")] = {
				"args": m_func.get_string("args"),
				"ret": ret if not ret.is_empty() else "void",
				"comment": comment_buffer.duplicate()
			}
			comment_buffer.clear()
			continue

		# Variable
		var m_var := re_var.search(line)
		if m_var:
			defs.vars[m_var.get_string("name")] = {
				"type": m_var.get_string("type"), "comment": comment_buffer.duplicate()
			}
			comment_buffer.clear()
			continue

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


## @brief 実装クラス（.gd）にボイラープレートを自動注入する
static func update_implements_boilerplate(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var source := f.get_as_text()
	f.close()

	var lines := source.split("\n")
	var ifc_names: Array[String] = []
	var re_marker := RegEx.new()
	re_marker.compile("(?m)^#\\s*implements\\s+(?<names>[\\w\\s,]+?)(?=\\r?$|\\n|$)")

	# マーカーを探す
	var m := re_marker.search(source)
	if not m:
		return  # マーカーがなければ何もしない

	for name in m.get_string("names").split(","):
		var n := name.strip_edges()
		if not n.is_empty():
			ifc_names.append(n)

	# ブロック定義タグ
	const LIST_START = "# --- INTERFACE LIST (AUTO-GENERATED) ---"
	const IMPL_START = "# --- INTERFACE IMPLEMENTER (AUTO-GENERATED) ---"
	const IMPL_END = "# --- END INTERFACE IMPLEMENTER ---"
	const VAR_START = "# --- INTERFACE VARIABLES (STUBS) ---"
	const VAR_END = "# --- END INTERFACE VARIABLES ---"
	const STUB_START = "# --- INTERFACE METHODS (STUBS) ---"
	const STUB_END = "# --- END INTERFACE METHODS ---"

	# すでにブロックが存在するかチェック
	var has_list_block := source.contains(LIST_START)
	var has_impl_block := source.contains(IMPL_START)
	var has_var_block := source.contains(VAR_START)
	var has_stub_block := source.contains(STUB_START)
	var has_manual_impl := (
		source.contains("func get_implementer") or source.contains("func set_implementer")
	)

	# 全て揃っているなら終了
	if has_list_block and (has_impl_block or has_manual_impl) and has_var_block and has_stub_block:
		return

	# 末尾の空行を掃除
	while lines.size() > 0 and lines[-1].strip_edges().is_empty():
		lines.remove_at(lines.size() - 1)

	# LISTブロック
	if not has_list_block:
		lines.append("")
		lines.append(LIST_START)
		lines.append("static func implements_list() -> Array[Script]:")
		lines.append("	return [{0}]".format([", ".join(ifc_names)]))
		lines.append("# --- END INTERFACE LIST ---")

	# IMPLEMENTERブロック
	if not has_impl_block and not has_manual_impl:
		lines.append("")
		lines.append(IMPL_START)
		lines.append("func get_implementer(_t: Script) -> Object:")
		lines.append("	return self")
		lines.append(IMPL_END)

	# 共通の定義抽出処理
	var all_defs: Array[Dictionary] = []
	for ifc_name in ifc_names:
		var ifc_path := _find_ifc_path_by_name(ifc_name)
		if ifc_path.is_empty():
			continue
		var ifc_file := FileAccess.open(ifc_path, FileAccess.READ)
		all_defs.append({"name": ifc_name, "defs": _parse_single_ifc(ifc_file.get_as_text())})
		ifc_file.close()

	# VARIABLES (STUBS)ブロック
	if not has_var_block:
		var var_stubs: Array[String] = []
		for item in all_defs:
			for var_name: String in item.defs.vars:
				var re_var_check := RegEx.new()
				re_var_check.compile("(?m)^\\s*var\\s+" + var_name + "(\\s*[:=]|\\s*$)")
				if re_var_check.search(source):
					continue

				var d: Dictionary = item.defs.vars[var_name]
				var_stubs.append("\n## @interface {0}".format([item.name]))
				var_stubs.append("var {0}: {1}".format([var_name, d.type]))

		if not var_stubs.is_empty():
			lines.append("\n" + VAR_START)
			lines.append_array(var_stubs)
			lines.append(VAR_END)

	# METHODS (STUBS)ブロック
	if not has_stub_block:
		var func_stubs: Array[String] = []
		for item in all_defs:
			for func_name: String in item.defs.funcs:
				var re_func_check := RegEx.new()
				# 行頭(または空白後)に func があり、コメントアウトされていないことを確認
				re_func_check.compile("(?m)^\\s*func\\s+" + func_name + "\\s*\\(")
				if re_func_check.search(source):
					continue

				var d: Dictionary = item.defs.funcs[func_name]
				func_stubs.append("\n## @interface {0}".format([item.name]))
				func_stubs.append("func {0}({1}) -> {2}:".format([func_name, d.args, d.ret]))
				func_stubs.append("	pass # TODO: Implement")

		if not func_stubs.is_empty():
			lines.append("\n" + STUB_START)
			lines.append_array(func_stubs)
			lines.append(STUB_END)

	lines.append("")
	var new_source := "\n".join(lines)
	if source != new_source:
		var fw := FileAccess.open(path, FileAccess.WRITE)
		fw.store_string(new_source)
		fw.close()
		print("[Interface] Injected missing boilerplate for: ", path.get_file())


## @brief クラス名(IMover)から対応する .ifc パスを探索する
static func _find_ifc_path_by_name(cls: String) -> String:
	var target_file := cls.to_snake_case()
	if not target_file.begins_with("i_"):
		target_file = "i_" + target_file
	target_file += ".ifc"

	return _search_file_recursive("res://", target_file)


static func _search_file_recursive(dir_path: String, target_name: String) -> String:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return ""
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			var res := _search_file_recursive(dir_path.path_join(file_name), target_name)
			if res != "":
				return res
		elif file_name == target_name:
			return dir_path.path_join(file_name)
		file_name = dir.get_next()
	return ""
