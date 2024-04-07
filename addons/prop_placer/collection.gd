@tool
extends Resource

@export var name: String = ""
@export var assets: Array[Dictionary] = []

func _init(_name: String = "") -> void:
    self.name = _name