extends Node2D

const OK_CHILD_IF = preload("uid://o60xl0k1edwk")
const OK_IF = preload("uid://cwbmudlob40n")
var impl_obj := CharacterBody2D.new()


static func implements_list() -> Array[GDScript]:
	return [
		OK_CHILD_IF,
		OK_IF,
	]


func get_implementer(t_if: GDScript) -> Object:
	match t_if:
		OK_CHILD_IF:
			return impl_obj
		_:
			return self
