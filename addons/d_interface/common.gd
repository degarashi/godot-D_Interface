@abstract class Getter:
	@abstract func get_it(scr: Script) -> Array
	@abstract func class_get(name: StringName) -> Array


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


static func _get_it(scr: Script, getter: Getter, name: String) -> Variant:
	for m in getter.get_it(scr):
		if m.name == name:
			return m
	var base := scr.get_base_script()
	if base != null:
		return _get_it(base, getter, name)

	var base_name := scr.get_instance_base_type()
	if base_name != "":
		for m in getter.class_get(base_name):
			if m.name == name:
				return m
	return null


static func get_method(scr: Script, name: String) -> Variant:
	return _get_it(scr, MethodGetter.new(), name)


static func get_property(scr: Script, name: String) -> Variant:
	return _get_it(scr, PropertyGetter.new(), name)


static func get_signal(scr: Script, name: String) -> Variant:
	return _get_it(scr, SignalGetter.new(), name)
