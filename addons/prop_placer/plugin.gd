@tool
extends EditorPlugin

const plugin_name := "Prop Placer"

const preview_size: int = 128

const GuiHandler := preload("res://addons/prop_placer/gui_handler.gd")
const Collection := preload("res://addons/prop_placer/collection.gd")
var gui := preload("res://addons/prop_placer/gui.tscn")

var gui_instance: GuiHandler

enum Mode {
	FREE,
	PLANE,
	FILL,
}

var current_mode := Mode.FREE

var root_node: Node
var scene_root: Node

var undo_redo: EditorUndoRedoManager

var plugin_enabled := true
var snapping_enabled := false
# TODO: change to Vector3
var snapping_step := 1.0
var snapping_offset := 0.0
var plane := Plane(Vector3.UP, 0.0)
var plane_normal: int = 0
var align_to_surface := false
var icon_size : int = 4
var base_scale := 1.0
var random_scale := 0.0
var chance_to_spawn: int = 100

# String (uid), Collection
var collections: Dictionary

var brush: Node3D
var selected_asset_uids: Array[String]

var rotation := Vector3.ZERO

var grid_mesh: MeshInstance3D
var grid_display_enabled := true

var fill_mesh: MeshInstance3D

func _enter_tree() -> void:
	scene_root = EditorInterface.get_edited_scene_root()

	scene_changed.connect(_on_scene_changed)
	scene_closed.connect(_on_scene_closed)

	gui_instance = gui.instantiate() as GuiHandler
	gui_instance.prop_placer_instance = self
	
	gui_instance.version_label.text = plugin_name + " v" + get_plugin_version()
	add_control_to_bottom_panel(gui_instance, plugin_name)

	undo_redo = get_undo_redo()

	setup_grid_mesh()
	setup_fill_mesh()

func setup_grid_mesh() -> void:
	grid_mesh = MeshInstance3D.new()
	grid_mesh.mesh = PlaneMesh.new()
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://addons/prop_placer/grid.gdshader")
	grid_mesh.mesh.surface_set_material(0, shader_material)
	grid_mesh.hide()

func setup_fill_mesh() -> void:
	fill_mesh = MeshInstance3D.new()
	fill_mesh.mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	material.albedo_color.a = 0.1
	fill_mesh.mesh.surface_set_material(0, material)
	fill_mesh.hide()
	add_child(fill_mesh)

func _exit_tree() -> void:
	remove_control_from_bottom_panel(gui_instance)
	gui_instance.free()
	if brush:
		brush.free()
	grid_mesh.free()
	fill_mesh.free()

func _get_plugin_name() -> String:
	return plugin_name

func _edit(object: Object) -> void:
	set_root_node(object)

func _on_scene_changed(_scene_root: Node) -> void:
	if is_instance_valid(self.scene_root):
		if is_instance_valid(brush):
			self.scene_root.remove_child(brush)
		if is_instance_valid(grid_mesh):
			self.scene_root.remove_child(grid_mesh)
	
	self.scene_root = _scene_root

	if is_instance_valid(self.scene_root):
		if is_instance_valid(brush):
			self.scene_root.add_child(brush)
		if is_instance_valid(grid_mesh):
			self.scene_root.add_child(grid_mesh)

func _on_scene_closed(path: String) -> void:
	if scene_root and scene_root.scene_file_path == path:
		if is_instance_valid(brush):
			self.scene_root.remove_child(brush)
		if is_instance_valid(grid_mesh):
			self.scene_root.remove_child(grid_mesh)

func _handles(object: Object) -> bool:
	return object is Node

func set_root_node(node: Node) -> void:
	if node == null or not plugin_enabled:
		if grid_mesh:
			grid_mesh.hide()
		if brush:
			brush.hide()
	else:
		if not selected_asset_uids.is_empty():
			if snapping_enabled:
				set_grid_visible(grid_display_enabled)
			if brush:
				brush.show()
	
	root_node = node

func change_mode(new_mode: Mode) -> void:
	# Mode exiting logic
	match current_mode:
		Mode.FREE:
			gui_instance.surface_container.hide()
		Mode.PLANE:
			gui_instance.plane_container.hide()
			set_grid_visible(false)
		Mode.FILL:
			gui_instance.plane_container.hide()
			gui_instance.chance_to_spawn_container.hide()
			set_grid_visible(false)

	current_mode = new_mode
	gui_instance.mode_option.selected = current_mode

	# Mode entering logic
	match current_mode:
		Mode.FREE:
			gui_instance.surface_container.show()
		Mode.PLANE:
			gui_instance.plane_container.show()
			if snapping_enabled:
				set_grid_visible(grid_display_enabled)
		Mode.FILL:
			gui_instance.plane_container.show()
			gui_instance.chance_to_spawn_container.show()
			if snapping_enabled:
				set_grid_visible(grid_display_enabled)

var fill_bounding_box: AABB

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if not plugin_enabled:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if selected_asset_uids.is_empty() or not root_node:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	brush.rotation = rotation

	match current_mode:
		Mode.FREE:
			var result := raycast(viewport_camera)
			if not result.is_empty():
				if snapping_enabled:
					result.position = result.position.snapped(Vector3(snapping_step, snapping_step, snapping_step))
				if align_to_surface:
					brush.transform = align_with_normal(brush.transform, result.normal)

				brush.position = result.position
		
		Mode.PLANE, Mode.FILL:
			var result: Variant = raycast_plane(viewport_camera)
			if result != null:
				result = result as Vector3

				grid_mesh.mesh.surface_get_material(0).set_shader_parameter("mouse_world_position", result)

				if snapping_enabled:
					result = result.snapped(Vector3(snapping_step, snapping_step, snapping_step))
					result += Vector3(snapping_offset, snapping_offset, snapping_offset)
					grid_mesh.position = result


				# TODO: maybe use transform instead of just position to avoid this
				match plane_normal:
					0:
						result.y = plane.d
						grid_mesh.position.y = plane.d + 0.01
					1:
						result.z = plane.d
						grid_mesh.position.z = plane.d + 0.01
					2:
						result.x = plane.d
						grid_mesh.position.x = plane.d + 0.01
				
				brush.position = result

				if current_mode == Mode.FILL:
					fill_bounding_box.size = brush.position - fill_bounding_box.position
					fill_mesh.position = fill_bounding_box.get_center()
					fill_mesh.position.y += snapping_step * 0.5
					fill_mesh.mesh.size = fill_bounding_box.size.abs() + Vector3.ONE * snapping_step

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if current_mode != Mode.FILL:
					if event.is_pressed():
						var asset_uid: String = selected_asset_uids.pick_random()
						place_asset(asset_uid, brush.position)
						return EditorPlugin.AFTER_GUI_INPUT_STOP
				elif snapping_enabled:
					if event.is_pressed():
						fill_bounding_box.position = brush.position
						fill_bounding_box.size = brush.position - fill_bounding_box.position
						fill_mesh.position = fill_bounding_box.get_center()
						fill_mesh.position.y += snapping_step * 0.5
						fill_mesh.mesh.size = fill_bounding_box.size.abs() + Vector3.ONE * snapping_step
						fill_mesh.show()
					else:
						fill_mesh.hide()
						fill_bounding_box.size = brush.position - fill_bounding_box.position
						fill(fill_bounding_box)
					return EditorPlugin.AFTER_GUI_INPUT_STOP
			
			MOUSE_BUTTON_RIGHT:
				if event.is_pressed():
					rotation.y = wrapf(rotation.y + (PI/4.0), 0.0, TAU)
					return EditorPlugin.AFTER_GUI_INPUT_STOP
			
			MOUSE_BUTTON_WHEEL_DOWN:
				if Input.is_key_pressed(KEY_CTRL):
					if event.is_pressed():
						plane.d -= snapping_step
						gui_instance.plane_level.text = str(plane.d)
					return EditorPlugin.AFTER_GUI_INPUT_STOP
			
			MOUSE_BUTTON_WHEEL_UP:
				if Input.is_key_pressed(KEY_CTRL):
					if event.is_pressed():
						plane.d += snapping_step
						gui_instance.plane_level.text = str(plane.d)
					return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS

# TODO: rework
# taken from https://github.com/godotengine/godot/issues/85903#issuecomment-1846245217
func align_with_normal(xform: Transform3D, n2: Vector3) -> Transform3D:
	var n1 := xform.basis.y.normalized()
	var cosa := n1.dot(n2)
	if cosa >= 0.99:
		return xform
	var alpha := acos(cosa)
	var axis := n1.cross(n2).normalized()
	if axis == Vector3.ZERO:
		axis = Vector3.FORWARD # normals are in opposite directions
	return xform.rotated(axis, alpha)

func raycast_plane(camera: Camera3D) -> Variant:
	var mousepos := EditorInterface.get_editor_viewport_3d().get_mouse_position()
	return plane.intersects_ray(camera.project_ray_origin(mousepos), camera.project_ray_normal(mousepos) * 1000.0)

func raycast(camera: Camera3D) -> Dictionary:
	var space_state := camera.get_world_3d().direct_space_state
	var mousepos := EditorInterface.get_editor_viewport_3d().get_mouse_position()

	var origin := camera.project_ray_origin(mousepos)
	var end := origin + camera.project_ray_normal(mousepos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(origin, end)

	return space_state.intersect_ray(query)

func set_snapping_enabled(enabled: bool) -> void:
	snapping_enabled = enabled
	if grid_display_enabled:
		set_grid_visible(enabled)

func set_grid_visible(visible: bool) -> void:
	if plugin_enabled:
		if self.root_node and not selected_asset_uids.is_empty():
			if current_mode == Mode.PLANE or current_mode == Mode.FILL:
				grid_mesh.set_visible(visible)

func set_grid_display_enabled(enabled: bool) -> void:
	grid_display_enabled = enabled
	if snapping_enabled:
		set_grid_visible(enabled)

func set_plane_level(value: float) -> void:
	plane.d = value

func set_snapping_step(value: float) -> void:
	snapping_step = maxf(0.1, value)
	grid_mesh.mesh.surface_get_material(0).set_shader_parameter("grid_step", snapping_step)

func set_snapping_offset(value: float) -> void:
	snapping_offset = value

func _get_window_layout(configuration: ConfigFile) -> void:
	var collection_ids: Array[String] = []
	for uid: String in collections.keys():
		collection_ids.append(uid)
	
	configuration.set_value(plugin_name, "collections", collection_ids)

	configuration.set_value(plugin_name, "plugin_enabled", plugin_enabled)
	configuration.set_value(plugin_name, "snapping_enabled", snapping_enabled)
	configuration.set_value(plugin_name, "plane_level", plane.d)
	configuration.set_value(plugin_name, "snapping_step", snapping_step)
	configuration.set_value(plugin_name, "snapping_offset", snapping_offset)
	configuration.set_value(plugin_name, "align_to_surface", align_to_surface)
	configuration.set_value(plugin_name, "icon_size", icon_size)
	configuration.set_value(plugin_name, "base_scale", base_scale)
	configuration.set_value(plugin_name, "random_scale", random_scale)
	configuration.set_value(plugin_name, "plane_normal", plane_normal)
	configuration.set_value(plugin_name, "grid_display_enabled", grid_display_enabled)
	configuration.set_value(plugin_name, "current_mode", current_mode)
	configuration.set_value(plugin_name, "chance_to_spawn", chance_to_spawn)

func _set_window_layout(configuration: ConfigFile) -> void:
	var collection_ids: Array[String] = configuration.get_value(plugin_name, "collections", [])

	for uid: String in collection_ids:
		if ResourceUID.has_id(ResourceUID.text_to_id(uid)):
			var res := ResourceLoader.load(uid) as Collection
			if res:
				collections[uid] = res

				gui_instance.spawn_collection_tab(uid, res)

	plugin_enabled = configuration.get_value(plugin_name, "plugin_enabled", plugin_enabled)
	gui_instance.enable_plugin_button.set_pressed_no_signal(plugin_enabled)

	change_mode(configuration.get_value(plugin_name, "current_mode", current_mode))

	snapping_enabled = configuration.get_value(plugin_name, "snapping_enabled", false)
	gui_instance.snapping_button.set_pressed_no_signal(snapping_enabled)

	plane.d = configuration.get_value(plugin_name, "plane_level", 0.0)
	gui_instance.plane_level.text = str(plane.d)

	set_snapping_step(configuration.get_value(plugin_name, "snapping_step", 1.0))
	gui_instance.snapping_step.text = str(snapping_step)

	snapping_offset = configuration.get_value(plugin_name, "snapping_offset", 0.0)
	gui_instance.snapping_offset.text = str(snapping_offset)

	align_to_surface = configuration.get_value(plugin_name, "align_to_surface", false)
	gui_instance.align_to_surface_button.set_pressed_no_signal(align_to_surface)

	icon_size = configuration.get_value(plugin_name, "icon_size", 4)
	gui_instance.icon_size_slider.set_value_no_signal(float(icon_size))
	gui_instance.set_collection_icon_size()

	base_scale = configuration.get_value(plugin_name, "base_scale", 1.0)
	gui_instance.base_scale.text = str(base_scale)

	random_scale = configuration.get_value(plugin_name, "random_scale", 0.0)
	gui_instance.random_scale.text = str(random_scale)

	plane_normal = configuration.get_value(plugin_name, "plane_normal", 0)
	gui_instance.plane_option.selected = plane_normal
	set_plane_normal(plane_normal)

	grid_display_enabled = configuration.get_value(plugin_name, "grid_display_enabled", true)
	gui_instance.display_grid_checkbox.set_pressed_no_signal(grid_display_enabled)

	chance_to_spawn = configuration.get_value(plugin_name, "chance_to_spawn", chance_to_spawn)
	gui_instance.chance_to_spawn.text = str(chance_to_spawn)

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

func change_brush(asset_uid: String) -> void:
	if brush:
		brush.free()
	var packedscene := ResourceLoader.load(asset_uid) as PackedScene

	if packedscene:
		var new_brush := packedscene.instantiate()
		brush = new_brush
		brush.scale = Vector3(base_scale, base_scale, base_scale)

		var brush_children := [brush]

		while not brush_children.is_empty():
			var child := brush_children.pop_back() as Node
			if child is CollisionObject3D or child is CSGShape3D:
				child.collision_layer = 0
			brush_children.append_array(child.get_children())

		if scene_root:
			scene_root.add_child(brush)

		if not root_node or not plugin_enabled:
			brush.hide()

func instantiate_asset(asset_uid: String) -> Node3D:
	var packedscene := ResourceLoader.load(asset_uid) as PackedScene

	if packedscene:
		var instance := packedscene.instantiate() as Node3D

		if not instance:
			return null

		var scale_range := 0.0
		if not is_zero_approx(random_scale):
			scale_range = randf_range(-random_scale, random_scale)
		instance.scale = Vector3(base_scale + scale_range, base_scale + scale_range, base_scale + scale_range)

		return instance
	return null

func place_asset(asset_uid: String, position: Vector3) -> void:
	var asset_instance := instantiate_asset(asset_uid)

	if asset_instance:
		undo_redo.create_action("Place Asset", UndoRedo.MERGE_DISABLE, scene_root)
		undo_redo.add_do_method(root_node, "add_child", asset_instance)
		undo_redo.add_do_property(asset_instance, "owner", scene_root)
		undo_redo.add_do_reference(asset_instance)
		undo_redo.add_undo_method(root_node, "remove_child", asset_instance)
		undo_redo.commit_action()

		asset_instance.global_position = position
		asset_instance.global_rotation = brush.rotation

func fill(bounding_box: AABB) -> void:
	bounding_box = bounding_box.abs()
	var steps_x := roundi(bounding_box.size.x / snapping_step) + 1
	var steps_y := roundi(bounding_box.size.y / snapping_step) + 1
	var steps_z := roundi(bounding_box.size.z / snapping_step) + 1

	var asset_instances: Array[Node3D]

	for x in range(steps_x):
		for y in range(steps_y):
			for z in range(steps_z):
				var random_number := randi_range(0, 100)

				if chance_to_spawn == 100 or chance_to_spawn > random_number:
					var asset_uid: String = selected_asset_uids.pick_random()
					var instance_position := Vector3(
						bounding_box.position.x + x * snapping_step,
						bounding_box.position.y + y * snapping_step,
						bounding_box.position.z + z * snapping_step
						)
					
					var asset_instance := instantiate_asset(asset_uid)
					asset_instance.position = instance_position
					asset_instance.rotation = brush.rotation
					asset_instances.append(asset_instance)
	
	if not asset_instances.is_empty():
		undo_redo.create_action("Fill Assets", UndoRedo.MERGE_DISABLE, scene_root)
		for asset_instance in asset_instances:
			if asset_instance:
				undo_redo.add_do_method(root_node, "add_child", asset_instance)
				undo_redo.add_do_property(asset_instance, "owner", scene_root)
				undo_redo.add_do_reference(asset_instance)
				undo_redo.add_undo_method(root_node, "remove_child", asset_instance)
		
		undo_redo.commit_action()

		# We can't apply global position before committing action, so we do it here instead.
		for asset_instance in asset_instances:
			if asset_instance:
				asset_instance.global_position = asset_instance.position
				asset_instance.global_rotation = asset_instance.rotation


func set_align_to_surface(value: bool) -> void:
	align_to_surface = value

func set_selected_assets(asset_uids: Array[String]) -> void:
	selected_asset_uids = asset_uids

	if not selected_asset_uids.is_empty():
		change_brush(selected_asset_uids[0])
		if snapping_enabled:
			set_grid_visible(grid_display_enabled)
	else:
		grid_mesh.hide()
		if brush:
			brush.free()

func set_base_scale(value: float) -> void:
	base_scale = value
	if brush:
		brush.scale = Vector3(base_scale, base_scale, base_scale)

func set_random_scale(value: float) -> void:
	random_scale = value

func set_plane_normal(normal: int) -> void:
	plane_normal = normal
	match plane_normal:
		0:
			plane.normal = Vector3.UP
			grid_mesh.rotation = Vector3.ZERO
		1:
			plane.normal = Vector3.BACK
			grid_mesh.rotation = Vector3(PI/2.0, 0.0, 0.0)
		2:
			plane.normal = Vector3.RIGHT
			grid_mesh.rotation = Vector3(0.0, 0.0, PI/2.0)

func set_chance_to_spawn(value: int) -> void:
	chance_to_spawn = clampi(value, 0, 100)

func set_plugin_enabled(enabled: bool) -> void:
	plugin_enabled = enabled
	set_root_node(root_node)
