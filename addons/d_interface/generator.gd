extends Object


## @brief .ifc ファイルの内容からブリッジ用GDScriptを生成する
static func generate_from_ifc(source_text: String, class_hint: String = "") -> String:
	var lines: Array[String] = []

	# --- 警告ヘッダーの挿入 ---
	lines.append("# " + "=".repeat(60))
	lines.append("#  WARNING: AUTO-GENERATED FILE. DO NOT EDIT MANUALLY.")
	lines.append("#  This file was generated from an .ifc definition.")
	lines.append("#  Any manual changes will be overwritten on the next generation.")
	lines.append("# " + "=".repeat(60))
	lines.append("")

	# 生成情報の追加
	var current_time := Time.get_datetime_string_from_system().replace("T", " ")
	lines.append("# Generated at: {0}".format([current_time]))
	lines.append("")

	# class_name の生成 (i_mover -> MoverBridge)
	if not class_hint.is_empty():
		var clean_name := class_hint.trim_prefix("i_").capitalize().replace(" ", "")
		lines.append("class_name I{0}".format([clean_name]))

	lines.append("extends InterfaceBase\n")

	# 正規表現の準備
	var re_func := RegEx.new()
	# func 名前(引数) -> 戻り値  をキャプチャ
	re_func.compile("func\\s+(?<name>\\w+)\\s*\\((?<args>.*)\\)\\s*(->\\s*(?<ret>[\\w.]+))?")

	var re_var := RegEx.new()
	# var 名前: 型  をキャプチャ
	re_var.compile("var\\s+(?<name>\\w+)\\s*:\\s*(?<type>[\\w.]+)")

	for raw_line in source_text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue

		# メソッドの解析
		var m_func := re_func.search(line)
		if m_func:
			var name := m_func.get_string("name")
			var args := m_func.get_string("args")
			var ret := m_func.get_string("ret")
			if ret.is_empty():
				ret = "void"

			lines.append("func {0}({1}) -> {2}:".format([name, args, ret]))
			lines.append("	return _impl.{0}({1})".format([name, _extract_arg_names(args)]))
			lines.append("")
			continue

		# 変数の解析
		var m_var := re_var.search(line)
		if m_var:
			var name := m_var.get_string("name")
			var type := m_var.get_string("type")

			lines.append("# Prop: {0}".format([name]))
			lines.append("var {0}: {1}:".format([name, type]))
			lines.append("	set(v): _impl.{0} = v".format([name]))
			lines.append("	get: return _impl.{0}".format([name]))
			lines.append("")

	return "\n".join(lines)


## @brief "val: Object, cb: Callable" から "val, cb" を抽出する
static func _extract_arg_names(args_str: String) -> String:
	if args_str.strip_edges().is_empty():
		return ""
	var names: Array[String] = []
	for part in args_str.split(","):
		var kv := part.split(":")
		names.append(kv[0].strip_edges())
	return ", ".join(names)
