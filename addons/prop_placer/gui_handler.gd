@tool
extends Control

# TODO: fix root button text overflow

const PropPlacer = preload("res://addons/prop_placer/plugin.gd")
const Collection := preload("res://addons/prop_placer/collection.gd")
const CollectionList := preload("res://addons/prop_placer/collection_list.gd")

var prop_placer_instance: PropPlacer

@export var preview_viewport: SubViewport
@export var preview_camera: Camera3D

@export var root_node_button: Button
@export var grid_button: CheckBox
@export var grid_level: LineEdit
@export var grid_step: LineEdit
@export var grid_offset: LineEdit
@export var new_collection_name: LineEdit
@export var new_collection_button: Button
@export var import_button: Button
@export var align_to_surface_button: CheckBox
@export var help_button: Button
@export var help_dialog: AcceptDialog
@export var version_label: Label
@export var icon_size_slider: HSlider

@export var collection_tabs: TabContainer

func _ready() -> void:
    root_node_button.pressed.connect(_on_root_node_button_pressed)
    grid_button.toggled.connect(_on_grid_toggled)
    grid_level.text_changed.connect(_on_grid_level_text_changed)
    grid_step.text_changed.connect(_on_grid_step_text_changed)
    grid_offset.text_changed.connect(_on_grid_offset_text_changed)
    new_collection_button.pressed.connect(_on_new_collection_button_pressed)
    import_button.pressed.connect(_on_import_button_pressed)
    align_to_surface_button.toggled.connect(_on_align_to_surface_toggled)
    help_button.pressed.connect(_on_help_button_pressed)
    icon_size_slider.value_changed.connect(_on_icon_size_slider_value_changed)

func _on_icon_size_slider_value_changed(_value: float) -> void:
    var value = int(_value)
    prop_placer_instance.icon_size = value
    set_collection_icon_size()

func _on_root_node_button_pressed() -> void:
    if prop_placer_instance.root_node:
        prop_placer_instance.set_root_node(null)
        return
    EditorInterface.popup_node_selector(_on_root_node_selected)

func _on_help_button_pressed() -> void:
    help_dialog.visible = true

func _on_align_to_surface_toggled(toggled: bool) -> void:
    prop_placer_instance.set_align_to_surface(toggled)

func _on_new_collection_button_pressed() -> void:
    var collection_name = new_collection_name.text

    if collection_name.is_empty():
        collection_name = "[No Name]"

    var save_dialog = EditorFileDialog.new()
    save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
    save_dialog.add_filter("*.tres", "Collection")
    EditorInterface.popup_dialog_centered(save_dialog)

    save_dialog.file_selected.connect(file_callback.bind(collection_name))

func _on_import_button_pressed() -> void:
    var load_dialog = EditorFileDialog.new()
    load_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
    load_dialog.add_filter("*.tres", "Collection")
    EditorInterface.popup_dialog_centered(load_dialog)

    load_dialog.files_selected.connect(import_dialog_callback)

func import_dialog_callback(paths: PackedStringArray) -> void:
    for path in paths:
        var collection := ResourceLoader.load(path) as Collection

        if collection:
            var uid := ResourceUID.id_to_text(ResourceLoader.get_resource_uid(path))

            if not prop_placer_instance.collections.has(uid):
                prop_placer_instance.collections[uid] = collection
                spawn_collection_tab(uid, collection)

func _on_root_node_selected(path: NodePath) -> void:
    if not path.is_empty():
        prop_placer_instance.set_root_node(prop_placer_instance.scene_root.get_node(path))

func _on_grid_toggled(toggled: bool) -> void:
    prop_placer_instance.set_grid_enabled(toggled)
    
    #prop_placer_instance.collections.clear()
    # for i: Collection in prop_placer_instance.collections:
    #     if i.assets.size() != 0:
    #         print(i.resource_path)

func _on_grid_level_text_changed(text: String) -> void:
    prop_placer_instance.set_grid_level(float(text)) # God forgive me

func _on_grid_step_text_changed(text: String) -> void:
    prop_placer_instance.set_grid_step(float(text))

func _on_grid_offset_text_changed(text: String) -> void:
    prop_placer_instance.set_grid_offset(float(text))

func file_callback(path: String, collection_name: String) -> void:
    var collection = Collection.new(collection_name)
    
    if ResourceSaver.save(collection, path) == OK:
        var uid := ResourceUID.id_to_text(ResourceLoader.get_resource_uid(path))
        prop_placer_instance.collections[uid] = collection
        collection.take_over_path(path)

        spawn_collection_tab(uid, collection)

        new_collection_name.text = ""

func set_collection_icon_size() -> void:
    for collection_list: CollectionList in collection_tabs.get_children():
        collection_list.icon_scale = prop_placer_instance.icon_size / 4.0

func spawn_collection_tab(uid: String, collection: Collection) -> void:
    var collection_list := CollectionList.new()
    collection_list.set_meta("uid", uid)
    collection_list.name = collection.name
    collection_list.max_columns = 0
    collection_list.fixed_icon_size = Vector2i(prop_placer_instance.preview_size, prop_placer_instance.preview_size)
    collection_list.icon_scale = prop_placer_instance.icon_size / 4.0
    collection_list.icon_mode = ItemList.ICON_MODE_TOP

    for asset: Dictionary in collection.assets:
        add_asset_to_tab(collection_list, asset)

    collection_list.data_dropped.connect(_on_data_dropped)
    collection_list.item_clicked.connect(_on_asset_clicked)

    collection_tabs.add_child(collection_list)

func _on_asset_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
    var current_tab := collection_tabs.get_child(collection_tabs.current_tab) as CollectionList

    match mouse_button_index:
        1:
            prop_placer_instance.change_brush(prop_placer_instance.collections[current_tab.get_meta("uid")].assets[index])
        2:
            current_tab.remove_item(index)
            # TODO: don't rely on index
            prop_placer_instance.collections[current_tab.get_meta("uid")].assets.remove_at(index)
        _:
            return

func _on_data_dropped(data: Variant) -> void:
    var current_tab := collection_tabs.current_tab

    for filepath: String in data["files"]:
        var packedscene = ResourceLoader.load(filepath) as PackedScene

        if packedscene:
            if packedscene.get_state().get_node_count() == 0:
                return
            
            var root_node_name := packedscene.get_state().get_node_name(0)
            var node = packedscene.instantiate()

            var preview := await prop_placer_instance.generate_preview(node)

            var tab := collection_tabs.get_child(current_tab) as CollectionList

            var asset := Dictionary()
            asset.thumbnail = preview
            asset.name = root_node_name
            asset.uid = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(filepath))

            prop_placer_instance.collections[collection_tabs.get_child(current_tab).get_meta("uid")].assets.append(asset)
            add_asset_to_tab(collection_tabs.get_child(current_tab), asset)


func add_asset_to_tab(tab: CollectionList, asset: Dictionary) -> void:
    tab.add_item(asset.name, asset.thumbnail)