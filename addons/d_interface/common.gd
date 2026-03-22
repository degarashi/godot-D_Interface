extends Object


# ------------- [Helper Classes] -------------
class Getter:
	func get_it(_scr: Script) -> Array:
		return []

	func class_get(_name: StringName) -> Array:
		return []


class MethodGetter:
	extends Getter

	func get_it(scr: Script) -> Array:
		return scr.get_script_method_list()

	func class_get(name: StringName) -> Array:
		return ClassDB.class_get_method_list(name)


class PropertyGetter:
	extends Getter

	func get_it(scr: Script) -> Array:
		return scr.get_script_property_list()

	func class_get(name: StringName) -> Array:
		return ClassDB.class_get_property_list(name)


class SignalGetter:
	extends Getter

	func get_it(scr: Script) -> Array:
		return scr.get_script_signal_list()

	func class_get(name: StringName) -> Array:
		return ClassDB.class_get_signal_list(name)


# ------------- [Private Static Method] -------------
static func _get_from_script(scr: Script, getter: Getter, name: String) -> Variant:
	for m: Dictionary in getter.get_it(scr):
		if m.name == name:
			return m

	var base: Script = scr.get_base_script()
	if base:
		return _get_from_script(base, getter, name)
	return null


static func _get_from_class(cls_name: StringName, getter: Getter, name: String) -> Variant:
	for m: Dictionary in getter.class_get(cls_name):
		if m.name == name:
			return m

	var parent: StringName = ClassDB.get_parent_class(cls_name)
	if parent != &"":
		return _get_from_class(parent, getter, name)
	return null


# ------------- [Public Static Method] -------------
## インスタンスから指定された要素（メソッド/プロパティ/シグナル）を検索する
static func get_it(target: Object, getter: Getter, name: String) -> Variant:
	if not target:
		return null

	var tgt: Object = target.get_script() if target is not Script else target
	var res := _get_from_script(tgt, getter, name)
	if res:
		return res

	return _get_from_class(target.get_class(), getter, name)


static func get_method(target: Object, name: String) -> Variant:
	return get_it(target, MethodGetter.new(), name)


static func get_property(target: Object, name: String) -> Variant:
	return get_it(target, PropertyGetter.new(), name)


static func get_signal(target: Object, name: String) -> Variant:
	return get_it(target, SignalGetter.new(), name)
