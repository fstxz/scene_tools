@tool
extends Resource

@export var name: String = ""
@export var assets: Array[Dictionary] = []

func _init(name: String = "") -> void:
    self.name = name