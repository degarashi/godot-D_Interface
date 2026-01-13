class_name InterfaceBase
extends Resource

@warning_ignore("unused_private_class_variable")
var _impl: Object


## call from Interface.as_interface()
func setup_interface(impl: Object) -> void:
	_impl = impl
	_on_setup_interface()


## [Virtual]
## call from InterfaceBase.setup_interface()
func _on_setup_interface() -> void:
	pass


func is_valid() -> bool:
	return _impl != null and is_instance_valid(_impl)
