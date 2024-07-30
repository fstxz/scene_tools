@tool
extends EditorPlugin

const plugin_name := "Scene Tools"

const preview_size: int = 128

const GuiHandler := preload("res://addons/scene_tools/gui_handler.gd")
const Tool := preload("res://addons/scene_tools/tool.gd")
const PlaceTool := preload("res://addons/scene_tools/tools/place.gd")
var gui := preload("res://addons/scene_tools/gui.tscn")

var gui_instance: GuiHandler

var root_node: Node
var scene_root: Node

var undo_redo: EditorUndoRedoManager

var plugin_enabled := false
var icon_size : int = 4

var selected_assets: Array

var side_panel_folded := true

var place_tool := PlaceTool.new(self)
var tools: Array[Tool] = [
    place_tool
]
var current_tool: Tool = place_tool

var tree: Tree
var files: ItemList

func _enter_tree() -> void:
    scene_changed.connect(_on_scene_changed)
    scene_closed.connect(_on_scene_closed)

    var gui_root := gui.instantiate()
    gui_instance = gui_root.get_node("SceneTools") as GuiHandler
    gui_instance.plugin_instance = self

    gui_instance.version_label.text = plugin_name + " v" + get_plugin_version()

    gui_instance.owner = null
    gui_root.remove_child(gui_instance)
    add_control_to_container(CustomControlContainer.CONTAINER_SPATIAL_EDITOR_MENU, gui_instance)

    gui_instance.side_panel.owner = null
    gui_root.remove_child(gui_instance.side_panel)
    add_control_to_container(CustomControlContainer.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, gui_instance.side_panel)

    gui_instance.scene_tools_button.pressed.connect(_scene_tools_button_pressed)

    undo_redo = get_undo_redo()

    setup_filesystem_signals()

    gui_root.free()
    current_tool.enter()

func _exit_tree() -> void:
    remove_control_from_container(CustomControlContainer.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, gui_instance.side_panel)
    remove_control_from_container(CustomControlContainer.CONTAINER_SPATIAL_EDITOR_MENU, gui_instance)
    gui_instance.side_panel.free()
    gui_instance.free()

    if tree != null:
        tree.multi_selected.disconnect(tree_selected)

    if files != null:
        files.multi_selected.disconnect(file_list_selected)

    for tool in tools:
        tool.exit()

func _make_visible(visible: bool) -> void:
    if visible:
        gui_instance.show()
        gui_instance.side_panel.set_visible(plugin_enabled)
    else:
        gui_instance.hide()
        gui_instance.side_panel.hide()

func _scene_tools_button_pressed() -> void:
    gui_instance.side_panel.set_visible(!gui_instance.side_panel.visible)
    set_plugin_enabled(!plugin_enabled)

func _get_plugin_name() -> String:
    return plugin_name

func _edit(object: Object) -> void:
    current_tool.edit(object)

func _on_scene_changed(_scene_root: Node) -> void:
    current_tool._on_scene_changed(_scene_root)

func _on_scene_closed(path: String) -> void:
    current_tool._on_scene_closed(path)

func _handles(object: Object) -> bool:
    return current_tool.handles(object)

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
    if not plugin_enabled or not root_node:
        return EditorPlugin.AFTER_GUI_INPUT_PASS

    return current_tool.forward_3d_gui_input(viewport_camera, event)

func _get_window_layout(configuration: ConfigFile) -> void:
    for tool in tools:
        tool.save_state(configuration)

func _set_window_layout(configuration: ConfigFile) -> void:
    for tool in tools:
        tool.load_state(configuration)

func generate_preview(node: Node) -> Texture2D:
    gui_instance.preview_viewport.add_child(node)
    gui_instance.preview_viewport.size = Vector2i(preview_size, preview_size)

    var aabb := get_aabb(node)

    if is_zero_approx(aabb.size.length()):
        return

    var max_size := max(aabb.size.x, aabb.size.y, aabb.size.z) as float

    gui_instance.preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    gui_instance.preview_camera.size = max_size * 2.0
    gui_instance.preview_camera.look_at_from_position(Vector3(max_size, max_size, max_size), aabb.get_center())

    await RenderingServer.frame_post_draw
    var viewport_image := gui_instance.preview_viewport.get_texture().get_image()
    var preview := PortableCompressedTexture2D.new()
    preview.create_from_image(viewport_image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY)

    gui_instance.preview_viewport.remove_child(node)
    node.queue_free()

    return preview

func get_aabb(node: Node) -> AABB:
    var aabb := AABB()

    var children: Array[Node] = []
    children.append(node)

    while not children.is_empty():
        var child := children.pop_back() as Node

        if child is VisualInstance3D:
            var child_aabb := child.get_aabb().abs() as AABB
            var transformed_aabb := AABB(child_aabb.position + child.global_position, child_aabb.size)
            aabb = aabb.merge(transformed_aabb)

        children.append_array(child.get_children())

    return aabb

# func set_selected_assets(asset_uids: Array[String]) -> void:
# 	selected_asset_uids = asset_uids

# 	if not selected_asset_uids.is_empty():
# 		place_tool.change_brush(selected_asset_uids[0])
# 		if place_tool.snapping_enabled:
# 			place_tool.set_grid_visible(place_tool.grid_display_enabled)
# 	else:
# 		place_tool.grid_mesh.hide()
# 		if place_tool.brush:
# 			place_tool.brush.free()

func set_plugin_enabled(enabled: bool) -> void:
    plugin_enabled = enabled
    current_tool._on_plugin_enabled(enabled)

func update_selected_assets() -> void:
    var new_selected := Array(EditorInterface.get_selected_paths())

    # Remove directories
    new_selected = new_selected.filter(func(path: String) -> bool:
        return not path.ends_with("/")
    )

    var remove_brush := false

    # if the amount of selected files changed
    if new_selected.size() != selected_assets.size():
        # if new_selected is not empty then try instantiating the first asset
        if not new_selected.is_empty():
            var scene := ResourceLoader.load(new_selected[0]) as PackedScene

            if scene:
                place_tool.change_brush(scene)
                if place_tool.snapping_enabled:
                    place_tool.set_grid_visible(place_tool.grid_display_enabled)
            else:
                remove_brush = true
        else:
            remove_brush = true
    # if the amount hasn't changed and there is one selected,
    # then compare newly selected with previously selected
    elif new_selected.size() == 1 and selected_assets.size() == 1:
        if new_selected[0] != selected_assets[0]:
            var scene := ResourceLoader.load(new_selected[0]) as PackedScene

            if scene:
                place_tool.change_brush(scene)
                if place_tool.snapping_enabled:
                    place_tool.set_grid_visible(place_tool.grid_display_enabled)
            else:
                remove_brush = true

    if remove_brush:
        place_tool.grid_mesh.hide()
        if place_tool.brush != null:
            place_tool.brush.free()

    selected_assets = new_selected

func setup_filesystem_signals() -> void:
    tree = EditorInterface.get_file_system_dock().find_child("@Tree*", true, false) as Tree
    files = EditorInterface.get_file_system_dock().find_child("@FileSystemList*", true, false) as ItemList

    if tree == null:
        push_error("[%s] Couldn't get FileSystemDock's tree" % plugin_name)
        return

    tree.multi_selected.connect(tree_selected)

    if files == null:
        push_error("[%s] Couldn't get FileSystemDock's file list" % plugin_name)
        return

    files.multi_selected.connect(file_list_selected)

func tree_selected(item: TreeItem, column: int, selected: bool) -> void:
    update_selected_assets()

func file_list_selected(index: int, selected: bool) -> void:
    update_selected_assets()
