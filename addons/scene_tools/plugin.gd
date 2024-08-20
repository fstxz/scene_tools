@tool
extends EditorPlugin

const plugin_name := "Scene Tools"

const GuiHandler := preload("res://addons/scene_tools/gui_handler.gd")
const Tool := preload("res://addons/scene_tools/tool.gd")
const PlaceTool := preload("res://addons/scene_tools/tools/place.gd")
var gui := preload("res://addons/scene_tools/gui.tscn")

var gui_instance: GuiHandler

var root_node: Node
var scene_root: Node

var undo_redo: EditorUndoRedoManager

var plugin_enabled := false

var selected_assets: Array

var side_panel_folded := true

var place_tool := PlaceTool.new(self)
var tools: Array[Tool] = [
    place_tool
]
var current_tool: Tool = place_tool

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

    gui_root.free()
    current_tool.enter()

func _exit_tree() -> void:
    remove_control_from_container(CustomControlContainer.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, gui_instance.side_panel)
    remove_control_from_container(CustomControlContainer.CONTAINER_SPATIAL_EDITOR_MENU, gui_instance)
    gui_instance.side_panel.free()
    gui_instance.free()

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

    update_selected_assets()

    return current_tool.forward_3d_gui_input(viewport_camera, event)

func _get_window_layout(configuration: ConfigFile) -> void:
    for tool in tools:
        tool.save_state(configuration)

func _set_window_layout(configuration: ConfigFile) -> void:
    for tool in tools:
        tool.load_state(configuration)

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
