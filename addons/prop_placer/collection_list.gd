@tool
extends ItemList

signal data_dropped(data: Variant)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
    return data["type"] == "files"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
    data_dropped.emit(data)