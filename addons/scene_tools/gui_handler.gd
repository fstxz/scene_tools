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
@export var align_to_surface_button: CheckBox
@export var help_dialog: AcceptDialog
@export var version_label: Label
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
@export var rotation_step: LineEdit

@export var side_panel: Control
@export var scene_tools_button: Button
@export var scene_tools_menu_button: MenuButton

func _ready() -> void:
    snapping_button.toggled.connect(_on_snapping_toggled)
    plane_level.text_changed.connect(_on_plane_level_text_changed)
    snapping_step.text_changed.connect(_on_snapping_step_text_changed)
    snapping_offset.text_changed.connect(_on_snapping_offset_text_changed)
    align_to_surface_button.toggled.connect(_on_align_to_surface_toggled)
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

    rotation_x.text_changed.connect(_on_rotation_x_text_changed)
    rotation_y.text_changed.connect(_on_rotation_y_text_changed)
    rotation_z.text_changed.connect(_on_rotation_z_text_changed)
    rotation_step.text_changed.connect(_on_rotation_step_text_changed)

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

func _on_scene_tools_menu_pressed(id: int) -> void:
    match id:
        0:
            help_dialog.visible = true

func _on_align_to_surface_toggled(toggled: bool) -> void:
    plugin_instance.place_tool.set_align_to_surface(toggled)

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

            plugin_instance.add_collection(uid, collection)

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

func add_asset_to_collection_list(to: CollectionList, asset: Dictionary) -> void:
    to.add_item(asset.name, asset.thumbnail)
    to.set_item_metadata(to.item_count-1, asset.uid)
    to.set_item_tooltip(to.item_count-1, asset.name + "\nFile: " + ResourceUID.get_id_path(ResourceUID.text_to_id(asset.uid)))

# _ because it clashes with the base class
func _set_rotation(value: Vector3) -> void:
    rotation_x.text = str(value.x)
    rotation_y.text = str(value.y)
    rotation_z.text = str(value.z)

func _set_scale(value: Vector3) -> void:
    scale_x.text = str(value.x)
    scale_y.text = str(value.y)
    scale_z.text = str(value.z)

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

func _on_rotation_step_text_changed(text: String) -> void:
    plugin_instance.place_tool.set_rotation_step(deg_to_rad(float(text)))
