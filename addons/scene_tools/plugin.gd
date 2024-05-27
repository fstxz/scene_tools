@tool
extends EditorPlugin

const plugin_name := "Scene Tools"

const preview_size: int = 128

const GuiHandler := preload("res://addons/scene_tools/gui_handler.gd")
const Collection := preload("res://addons/scene_tools/collection.gd")
const Tool := preload("res://addons/scene_tools/tool.gd")
const PlaceTool := preload("res://addons/scene_tools/tools/place.gd")
var gui := preload("res://addons/scene_tools/gui.tscn")

var gui_instance: GuiHandler

signal collection_removed(uid: String)

var root_node: Node
var scene_root: Node

var undo_redo: EditorUndoRedoManager

var plugin_enabled := false
var icon_size : int = 4

# Key: String (uid), Value: Collection
var collections: Dictionary

var selected_asset_uids: Array[String]

var side_panel_folded := true

var place_tool := PlaceTool.new(self)
var tools: Array[Tool] = [
	place_tool
]
var current_tool: Tool = place_tool

func _enter_tree() -> void:
	EditorInterface.get_file_system_dock().resource_removed.connect(_on_resource_removed)

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

	gui_instance.collections_container.owner = null
	gui_root.remove_child(gui_instance.collections_container)
	add_control_to_bottom_panel(gui_instance.collections_container, "Collections")

	gui_instance.scene_tools_button.pressed.connect(_scene_tools_button_pressed)

	undo_redo = get_undo_redo()

	gui_root.free()
	current_tool.enter()

func _exit_tree() -> void:
	remove_control_from_bottom_panel(gui_instance.collections_container)
	remove_control_from_container(CustomControlContainer.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT, gui_instance.side_panel)
	remove_control_from_container(CustomControlContainer.CONTAINER_SPATIAL_EDITOR_MENU, gui_instance)
	gui_instance.side_panel.free()
	gui_instance.collections_container.free()
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
	if not plugin_enabled:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if selected_asset_uids.is_empty() or not root_node:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	return current_tool.forward_3d_gui_input(viewport_camera, event)

func _get_window_layout(configuration: ConfigFile) -> void:
	var collection_ids: Array[String] = []
	for uid: String in collections.keys():
		collection_ids.append(uid)
	
	configuration.set_value(plugin_name, "collections", collection_ids)

	configuration.set_value(plugin_name, "icon_size", icon_size)
	
	for tool in tools:
		tool.save_state(configuration)

func _set_window_layout(configuration: ConfigFile) -> void:
	var collection_ids: Array[String] = configuration.get_value(plugin_name, "collections", [])

	for uid: String in collection_ids:
		if ResourceUID.has_id(ResourceUID.text_to_id(uid)):
			var res := ResourceLoader.load(uid) as Collection
			if res:
				add_collection(uid, res)

	icon_size = configuration.get_value(plugin_name, "icon_size", 4)
	gui_instance.icon_size_slider.set_value_no_signal(float(icon_size))
	gui_instance.set_collection_icon_size()

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

func _save_external_data() -> void:
	for collection: Collection in collections.values():
		ResourceSaver.save(collection)

func set_selected_assets(asset_uids: Array[String]) -> void:
	selected_asset_uids = asset_uids

	if not selected_asset_uids.is_empty():
		place_tool.change_brush(selected_asset_uids[0])
		if place_tool.snapping_enabled:
			place_tool.set_grid_visible(place_tool.grid_display_enabled)
	else:
		place_tool.grid_mesh.hide()
		if place_tool.brush:
			place_tool.brush.free()

func set_plugin_enabled(enabled: bool) -> void:
	plugin_enabled = enabled
	current_tool._on_plugin_enabled(enabled)

func _on_resource_removed(resource: Resource) -> void:
	var uid := ResourceUID.id_to_text(ResourceLoader.get_resource_uid(resource.resource_path))

	if collections.has(uid):
		collections.erase(uid)
		collection_removed.emit(uid)

# This removes assets from a collection if the UID is invalid 
# (asset deleted from filesystem or UID has changed for whatever reason)
func remove_orphan_assets(from: Collection) -> void:
	from.assets = from.assets.filter(func(asset: Dictionary) -> bool:
		return ResourceUID.has_id(ResourceUID.text_to_id(asset.uid))
	)

func add_collection(uid: String, collection: Collection) -> void:
	if not collections.has(uid):
		remove_orphan_assets(collection)
		collections[uid] = collection
		gui_instance.spawn_collection_list(uid, collection)
