extends InterfaceBase


func test_func(val: float, cb: Callable) -> float:
	return _impl.test_func(val, cb)


func test_func2(val0: float) -> float:
	return _impl.test_func2(val0, 0)
