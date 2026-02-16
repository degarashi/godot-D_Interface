@abstract class Error:
	@abstract func as_string() -> String


# ---------- [General bases] ----------
@abstract class ErrorWithTarget:
	extends Error
	var target_name: String

	func _init(target_name: String) -> void:
		self.target_name = target_name


@abstract class ErrorDifferArgumentNum:
	extends Error
	var expect: int
	var actual: int

	func _init(expect: int, actual: int) -> void:
		self.expect = expect
		self.actual = actual


@abstract class ErrorInvalidArgumentType:
	extends Error
	var expect_id: int
	var actual_id: int

	func _init(expect_id: int = -1, actual_id: int = -1) -> void:
		self.expect_id = expect_id
		self.actual_id = actual_id

	## 型IDを人可読文字列へ（必要なら差し替え）
	func _type_id_to_string(id: int) -> String:
		# プロジェクト固有の型テーブルがあれば置き換える
		return "Type({0})".format([type_string(id)])


@abstract class ErrorNotFound:
	extends ErrorWithTarget

	func as_string() -> String:
		# 具体クラスでプレフィックスを与える
		return "Not found: '%s'" % target_name


# ---------- [Argument count differ] ----------
class ErrorDifferMethodArgumentNum:
	extends ErrorDifferArgumentNum

	func as_string() -> String:
		return "Method argument count mismatch: expected=%d, actual=%d" % [expect, actual]


class ErrorDifferSignalArgumentNum:
	extends ErrorDifferArgumentNum

	func as_string() -> String:
		return "Signal argument count mismatch: expected=%d, actual=%d" % [expect, actual]


# ---------- [Invalid argument type] ----------
class ErrorInvalidMethodArgumentType:
	extends ErrorInvalidArgumentType

	func as_string() -> String:
		var expect_str := _type_id_to_string(expect_id)
		var actual_str := _type_id_to_string(actual_id)
		return "Invalid method argument type: expected=%s, actual=%s" % [expect_str, actual_str]


class ErrorInvalidSignalArgumentType:
	extends ErrorInvalidArgumentType

	func as_string() -> String:
		var expect_str := _type_id_to_string(expect_id)
		var actual_str := _type_id_to_string(actual_id)
		return "Invalid signal argument type: expected=%s, actual=%s" % [expect_str, actual_str]


# ---------- [Not founds] ----------
class ErrorSignalNotFound:
	extends ErrorNotFound

	func as_string() -> String:
		return "Signal not found: '%s'" % target_name


class ErrorMethodNotFound:
	extends ErrorNotFound

	func as_string() -> String:
		return "Method not found: '%s'" % target_name


class ErrorPropertyNotFound:
	extends ErrorNotFound

	func as_string() -> String:
		return "Property not found: '%s'" % target_name


# ---------- [Property differences] ----------
class ErrorPropertyNameDiffer:
	extends Error
	var expect_label: String
	var actual_label: String

	func _init(expect_label: String, actual_label: String) -> void:
		self.expect_label = expect_label
		self.actual_label = actual_label

	func as_string() -> String:
		return "Property name differs: expected='%s', actual='%s'" % [expect_label, actual_label]


class ErrorPropertyTypeDiffer:
	extends Error
	var prop_name: String
	var expect_type_id: int
	var actual_type_id: int

	func _init(p_name: String, expect_type_id: int, actual_type_id: int) -> void:
		self.prop_name = p_name
		self.expect_type_id = expect_type_id
		self.actual_type_id = actual_type_id

	func as_string() -> String:
		return (
			"Property type differs(%s): expected=%s, actual=%s"
			% [prop_name, type_string(expect_type_id), type_string(actual_type_id)]
		)


# ---------- [Argument property differ bases] ----------
@abstract class ErrorArgPropertyDifferBase:
	extends Error
	var owner_name: String
	var index: int
	var message: String

	func _init(owner_name: String, index: int, message: String) -> void:
		self.owner_name = owner_name
		self.index = index
		self.message = message


class ErrorMethodArgPropertyDiffer:
	extends ErrorArgPropertyDifferBase

	func as_string() -> String:
		return "Method '%s' arg[%d] %s" % [owner_name, index, message]


class ErrorSignalArgPropertyDiffer:
	extends ErrorArgPropertyDifferBase

	func as_string() -> String:
		return "Signal '%s' arg[%d] %s" % [owner_name, index, message]


# ---------- [Return type differ bases] ----------
@abstract class ErrorReturnTypeDifferBase:
	extends Error
	var owner_name: String
	var expect_type_id: int
	var actual_type_id: int

	func _init(owner_name: String, expect_type_id: int, actual_type_id: int) -> void:
		self.owner_name = owner_name
		self.expect_type_id = expect_type_id
		self.actual_type_id = actual_type_id

	func _format_types() -> Array:
		return [type_string(expect_type_id), type_string(actual_type_id)]


class ErrorMethodReturnTypeDiffer:
	extends ErrorReturnTypeDifferBase

	func as_string() -> String:
		var ts := _format_types()
		return (
			"Method '%s' return type differs: expected=%s, actual=%s" % [owner_name, ts[0], ts[1]]
		)


class ErrorSignalReturnTypeDiffer:
	extends ErrorReturnTypeDifferBase

	func as_string() -> String:
		var ts := _format_types()
		return (
			"Signal '%s' return type differs: expected=%s, actual=%s" % [owner_name, ts[0], ts[1]]
		)


# ---------- [Default arg mismatches] ----------
@abstract class ErrorMethodDefaultArgIssueBase:
	extends Error
	var method_name: String

	func _init(method_name: String) -> void:
		self.method_name = method_name


class ErrorMethodDefaultArgCountMismatch:
	extends ErrorMethodDefaultArgIssueBase
	var expect: int
	var actual: int

	func _init(method_name: String, expect: int, actual: int) -> void:
		super._init(method_name)
		self.expect = expect
		self.actual = actual

	func as_string() -> String:
		return (
			"Method '%s' default arg count mismatch: expected=%d, actual=%d"
			% [method_name, expect, actual]
		)


class ErrorMethodDefaultArgValueMismatch:
	extends ErrorMethodDefaultArgIssueBase
	var index: int
	var expect_val: Variant
	var actual_val: Variant

	func _init(method_name: String, index: int, expect_val: Variant, actual_val: Variant) -> void:
		super._init(method_name)
		self.index = index
		self.expect_val = expect_val
		self.actual_val = actual_val

	func as_string() -> String:
		return (
			"Method '%s' default arg[%d] value differs: expected=%s, actual=%s"
			% [method_name, index, str(expect_val), str(actual_val)]
		)
