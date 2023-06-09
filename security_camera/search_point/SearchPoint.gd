extends Node

class_name  SearchPoint


@export var waitTime:float = 1

func _ready():
	get_node("MeshInstance3D").hide()
