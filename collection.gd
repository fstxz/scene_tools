@tool
extends Resource

# const Asset := preload("res://addons/prop_placer/asset.gd")

@export var name: String = ""
@export var assets: Array[Dictionary] = []

func _init(name: String = "") -> void:
    self.name = name