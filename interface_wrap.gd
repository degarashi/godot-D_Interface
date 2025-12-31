class_name InterfaceWrap

var _obj: Array[Object]


func _init(objs: Array[Object]) -> void:
	_obj = objs


func get_implementer(t_if: Script) -> Object:
	for obj in _obj:
		if Interface.implemented(obj, t_if):
			return obj
	return null
