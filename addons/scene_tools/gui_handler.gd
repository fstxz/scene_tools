@tool
extends Control

const SceneTools = preload("res://addons/scene_tools/plugin.gd")
const Collection := preload("res://addons/scene_tools/collection.gd")
const CollectionList := preload("res://addons/scene_tools/collection_list.gd")

var plugin_instance: SceneTools

var preview_viewport: SubViewport
var preview_camera: Camera3D

@export var snapping_button: CheckBox
@export var snapping_step: LineEdit
@export var snapping_offset: LineEdit
@export var new_collection_name: LineEdit
@export var align_to_surface_button: CheckBox
@export var help_dialog: AcceptDialog
@export var version_label: Label
@export var icon_size_slider: HSlider
@export var random_rotation_button: CheckBox
@export var random_scale_button: CheckBox
@export var random_rotation_axis: OptionButton
@export var random_rotation: LineEdit
@export var scale_x: LineEdit
@export var scale_y: LineEdit
@export var scale_z: LineEdit
@export var rotation_x: LineEdit
@export var rotation_y: LineEdit
@export var rotation_z: LineEdit
@export var scale_link_button: Button
@export var random_scale: LineEdit
@export var plane_option: OptionButton
@export var display_grid_checkbox: CheckBox
@export var mode_option: OptionButton
@export var surface_container: Control
@export var plane_container: Control
@export var chance_to_spawn_container: Control
@export var chance_to_spawn: LineEdit
@export var plane_level: LineEdit
@export var file_menu: MenuButton
@export var new_collection_dialog: AcceptDialog
@export var collections_list: ItemList
@export var collections_items_container: Control

@export var side_panel: Control
@export var collections_container: Control
@export var scene_tools_button: Button
@export var scene_tools_menu_button: MenuButton

func _ready() -> void:
    snapping_button.toggled.connect(_on_snapping_toggled)
    plane_level.text_changed.connect(_on_plane_level_text_changed)
    snapping_step.text_changed.connect(_on_snapping_step_text_changed)
    snapping_offset.text_changed.connect(_on_snapping_offset_text_changed)
    align_to_surface_button.toggled.connect(_on_align_to_surface_toggled)
    icon_size_slider.value_changed.connect(_on_icon_size_slider_value_changed)
    random_scale.text_changed.connect(_on_random_scale_text_changed)
    plane_option.item_selected.connect(_on_plane_option_button_item_selected)
    display_grid_checkbox.toggled.connect(_on_display_grid_checkbox_toggled)
    mode_option.item_selected.connect(_on_mode_option_button_item_selected)
    chance_to_spawn.text_changed.connect(_on_chance_to_spawn_text_changed)
    scene_tools_menu_button.get_popup().id_pressed.connect(_on_scene_tools_menu_pressed)
    scale_link_button.toggled.connect(_on_scale_link_toggled)
    random_rotation_button.toggled.connect(_on_random_rotation_button_toggled)
    random_scale_button.toggled.connect(_on_random_scale_button_toggled)
    random_rotation_axis.item_selected.connect(_on_random_rotation_axis_item_selected)
    random_rotation.text_changed.connect(_on_random_rotation_text_changed)
    new_collection_dialog.confirmed.connect(_new_collection_dialog_confirmed)
    file_menu.get_popup().id_pressed.connect(_on_file_menu_pressed)
    collections_list.item_clicked.connect(_on_collection_clicked)
    collections_list.item_selected.connect(_on_collections_list_item_selected)

    rotation_x.text_changed.connect(_on_rotation_x_text_changed)
    rotation_y.text_changed.connect(_on_rotation_y_text_changed)
    rotation_z.text_changed.connect(_on_rotation_z_text_changed)

    scale_x.text_changed.connect(_on_scale_x_text_changed)
    scale_y.text_changed.connect(_on_scale_y_text_changed)
    scale_z.text_changed.connect(_on_scale_z_text_changed)

    setup_preview_viewport()

    # Hide mode specific containers
    surface_container.hide()
    plane_container.hide()
    chance_to_spawn_container.hide()
    side_panel.hide()

func setup_preview_viewport() -> void:
    preview_viewport = SubViewport.new()
    preview_viewport.size = Vector2i(plugin_instance.preview_size, plugin_instance.preview_size)
    preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    preview_viewport.transparent_bg = true
    preview_viewport.scaling_3d_mode = SubViewport.SCALING_3D_MODE_BILINEAR
    preview_viewport.own_world_3d = true
    preview_viewport.world_3d = World3D.new()
    preview_viewport.world_3d.environment = Environment.new()
    preview_viewport.world_3d.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    preview_viewport.world_3d.environment.ambient_light_color = Color(1.0, 1.0, 1.0, 1.0)

    preview_camera = Camera3D.new()
    preview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL

    preview_viewport.add_child(preview_camera)
    add_child(preview_viewport)


func _on_mode_option_button_item_selected(index: int) -> void:
    plugin_instance.place_tool.change_mode(index)

func _on_display_grid_checkbox_toggled(toggled: bool) -> void:
    plugin_instance.place_tool.set_grid_display_enabled(toggled)

func _on_plane_option_button_item_selected(index: int) -> void:
    plugin_instance.place_tool.set_plane_normal(index)

func _on_random_scale_text_changed(text: String) -> void:
    plugin_instance.place_tool.set_random_scale(float(text))

func remove_selected_collection() -> void:
    var collection := get_selected_collection()
    var uid: String = collection.get_meta("uid")
    collections_list.remove_item(collections_list.get_selected_items()[0])
    collection.free()
    ResourceSaver.save(plugin_instance.collections[uid])
    plugin_instance.collections.erase(uid)

    if collections_list.item_count > 0:
        collections_list.select(collections_list.item_count-1)

func _on_icon_size_slider_value_changed(_value: float) -> void:
    var value := int(_value)
    plugin_instance.icon_size = value
    set_collection_icon_size()

func _on_scene_tools_menu_pressed(id: int) -> void:
    match id:
        0:
            help_dialog.visible = true

func _on_file_menu_pressed(id: int) -> void:
    match id:
        # New collection
        0:
            new_collection_dialog.visible = true
        # Load Collection
        1:
            load_collection_dialog()

func _on_align_to_surface_toggled(toggled: bool) -> void:
    plugin_instance.place_tool.set_align_to_surface(toggled)

func _new_collection_dialog_confirmed() -> void:
    var collection_name := new_collection_name.text

    if collection_name.is_empty():
        collection_name = "[No Name]"

    var save_dialog := EditorFileDialog.new()
    save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
    save_dialog.add_filter("*.tres", "Collection")
    save_dialog.size = Vector2(800, 700)
    EditorInterface.popup_dialog_centered(save_dialog)

    save_dialog.file_selected.connect(new_collection_dialog_callback.bind(collection_name))
    new_collection_dialog.visible = false

func load_collection_dialog() -> void:
    var load_dialog := EditorFileDialog.new()
    load_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
    load_dialog.add_filter("*.tres", "Collection")
    load_dialog.size = Vector2(800, 700)
    EditorInterface.popup_dialog_centered(load_dialog)

    load_dialog.files_selected.connect(load_collection_dialog_callback)

func load_collection_dialog_callback(paths: PackedStringArray) -> void:
    for path in paths:
        var collection := ResourceLoader.load(path) as Collection

        if collection:
            var uid := ResourceUID.id_to_text(ResourceLoader.get_resource_uid(path))

            if not plugin_instance.collections.has(uid):
                plugin_instance.collections[uid] = collection
                spawn_collection_tab(uid, collection)

func _on_snapping_toggled(toggled: bool) -> void:
    plugin_instance.place_tool.set_snapping_enabled(toggled)

func _on_plane_level_text_changed(text: String) -> void:
    plugin_instance.place_tool.set_plane_level(float(text))

func _on_snapping_step_text_changed(text: String) -> void:
    plugin_instance.place_tool.set_snapping_step(float(text))

func _on_snapping_offset_text_changed(text: String) -> void:
    plugin_instance.place_tool.set_snapping_offset(float(text))

func _on_chance_to_spawn_text_changed(text: String) -> void:
    plugin_instance.place_tool.set_chance_to_spawn(int(text))

func new_collection_dialog_callback(path: String, collection_name: String) -> void:
    var collection := Collection.new(collection_name)
    
    if ResourceSaver.save(collection, path) == OK:
        var uid := ResourceUID.id_to_text(ResourceLoader.get_resource_uid(path))
        plugin_instance.collections[uid] = collection
        collection.take_over_path(path)

        spawn_collection_tab(uid, collection)

    new_collection_name.text = ""

func set_collection_icon_size() -> void:
    for collection_list: CollectionList in collections_items_container.get_children():
        collection_list.icon_scale = plugin_instance.icon_size / 4.0

func spawn_collection_tab(uid: String, collection: Collection) -> void:
    var collection_list := CollectionList.new()

    collections_list.add_item(collection.name)
    collections_list.set_item_metadata(collections_list.item_count-1, uid)
    collections_list.select(collections_list.item_count-1)

    collection_list.set_meta("uid", uid)
    collection_list.max_columns = 0
    collection_list.fixed_icon_size = Vector2i(plugin_instance.preview_size, plugin_instance.preview_size)
    collection_list.icon_scale = plugin_instance.icon_size / 4.0
    collection_list.icon_mode = ItemList.ICON_MODE_TOP
    collection_list.same_column_width = true
    collection_list.select_mode = ItemList.SELECT_MULTI

    for asset: Dictionary in collection.assets:
        add_asset_to_tab(collection_list, asset)

    collection_list.data_dropped.connect(_on_data_dropped)
    collection_list.item_clicked.connect(_on_asset_clicked)
    collection_list.multi_selected.connect(_on_item_selected)

    collections_items_container.add_child(collection_list)
    _on_collections_list_item_selected(collections_list.item_count-1)

func _on_item_selected(_index: int, _selected: bool) -> void:
    plugin_instance.set_selected_assets(get_selected_asset_uids())

func _on_asset_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
    var current_tab := get_selected_collection()

    match mouse_button_index:
        2:
            current_tab.remove_item(index)
            # TODO: don't rely on index
            plugin_instance.collections[current_tab.get_meta("uid")].assets.remove_at(index)
            plugin_instance.set_selected_assets(get_selected_asset_uids())
        _:
            return

func _on_collection_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
    match mouse_button_index:
        2:
            collections_list.select(index)
            remove_selected_collection()

func get_selected_asset_uids() -> Array[String]:
    var current_tab := get_selected_collection()

    var selected_items := current_tab.get_selected_items()
    var asset_uids: Array[String] = []
    for i: int in selected_items:
        asset_uids.append(plugin_instance.collections[current_tab.get_meta("uid")].assets[i].uid)
    
    return asset_uids

func _on_data_dropped(data: Variant) -> void:
    for filepath: String in data["files"]:
        var packedscene := ResourceLoader.load(filepath) as PackedScene

        if packedscene:
            if packedscene.get_state().get_node_count() == 0:
                return
            
            var root_node_name := packedscene.get_state().get_node_name(0)
            var node := packedscene.instantiate()

            var preview := await plugin_instance.generate_preview(node)

            var tab := get_selected_collection()

            var asset := Dictionary()
            asset.thumbnail = preview
            asset.name = root_node_name
            asset.uid = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(filepath))

            plugin_instance.collections[tab.get_meta("uid")].assets.append(asset)
            add_asset_to_tab(tab, asset)


func add_asset_to_tab(tab: CollectionList, asset: Dictionary) -> void:
    tab.add_item(asset.name, asset.thumbnail)

# _ because it clashes with the base class
func _set_rotation(rotation: Vector3) -> void:
    rotation_x.text = str(rotation.x)
    rotation_y.text = str(rotation.y)
    rotation_z.text = str(rotation.z)

func _set_scale(scale: Vector3) -> void:
    scale_x.text = str(scale.x)
    scale_y.text = str(scale.y)
    scale_z.text = str(scale.z)

func _on_scale_link_toggled(toggled: bool) -> void:
    plugin_instance.place_tool.set_scale_link_toggled(toggled)

func _on_random_rotation_button_toggled(toggled: bool) -> void:
    plugin_instance.place_tool.set_random_rotation_enabled(toggled)

func _on_random_scale_button_toggled(toggled: bool) -> void:
    plugin_instance.place_tool.set_random_scale_enabled(toggled)

func _on_random_rotation_axis_item_selected(index: int) -> void:
    plugin_instance.place_tool.set_random_rotation_axis(index)

func _on_rotation_x_text_changed(text: String) -> void:
    plugin_instance.place_tool.set_rotation(Vector3(
        deg_to_rad(float(text)),
        plugin_instance.place_tool.rotation.y,
        plugin_instance.place_tool.rotation.z
        ))

func _on_rotation_y_text_changed(text: String) -> void:
    plugin_instance.place_tool.set_rotation(Vector3(
        plugin_instance.place_tool.rotation.x,
        deg_to_rad(float(text)),
        plugin_instance.place_tool.rotation.z
        ))

func _on_rotation_z_text_changed(text: String) -> void:
    plugin_instance.place_tool.set_rotation(Vector3(
        plugin_instance.place_tool.rotation.x,
        plugin_instance.place_tool.rotation.y,
        deg_to_rad(float(text))
        ))

func _on_random_rotation_text_changed(text: String) -> void:
    plugin_instance.place_tool.set_random_rotation(deg_to_rad(float(text)))

func _on_scale_x_text_changed(text: String) -> void:
    if plugin_instance.place_tool.scale_linked:
        plugin_instance.place_tool.set_base_scale(Vector3(float(text), float(text), float(text)))
        _set_scale(plugin_instance.place_tool.base_scale)
    else:
        plugin_instance.place_tool.set_base_scale(Vector3(
            float(text),
            plugin_instance.place_tool.base_scale.y,
            plugin_instance.place_tool.base_scale.z
            ))

func _on_scale_y_text_changed(text: String) -> void:
    if plugin_instance.place_tool.scale_linked:
        plugin_instance.place_tool.set_base_scale(Vector3(float(text), float(text), float(text)))
        _set_scale(plugin_instance.place_tool.base_scale)
    else:
        plugin_instance.place_tool.set_base_scale(Vector3(
            plugin_instance.place_tool.base_scale.x,
            float(text),
            plugin_instance.place_tool.base_scale.z
            ))

func _on_scale_z_text_changed(text: String) -> void:
    if plugin_instance.place_tool.scale_linked:
        plugin_instance.place_tool.set_base_scale(Vector3(float(text), float(text), float(text)))
        _set_scale(plugin_instance.place_tool.base_scale)
    else:
        plugin_instance.place_tool.set_base_scale(Vector3(
            plugin_instance.place_tool.base_scale.x,
            plugin_instance.place_tool.base_scale.y,
            float(text)
            ))

func get_selected_collection() -> CollectionList:
    return collections_items_container.get_child(collections_list.get_selected_items()[0])

func _on_collections_list_item_selected(index: int) -> void:
    if collections_list.item_count > 0:
        for child: Control in collections_items_container.get_children():
            child.visible = false
        collections_items_container.get_child(index).visible = true
