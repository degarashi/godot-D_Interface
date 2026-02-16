extends InterfaceBase

enum Status { SUCCESS, FAILURE, RUNNING }

# Prop: velocity
var velocity: Vector2:
	set(v):
		_impl.velocity = v
	get:
		return _impl.velocity

# Prop: global_position
var global_position: Vector2:
	set(v):
		_impl.global_position = v
	get:
		return _impl.global_position


func test_child_func(value_i: int, value_f: float) -> String:
	return _impl.test_child_func(value_i, value_f)


func test_child_func2() -> void:
	return _impl.test_child_func2()
