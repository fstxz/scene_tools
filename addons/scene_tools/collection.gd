@tool
extends Resource

@export var name: String = ""
# Asset dictionary: "uid": String, "name": String, "thumbnail": PortableCompressedTexture2D
@export var assets: Array[Dictionary] = []

func _init(_name: String = "") -> void:
    self.name = _name
