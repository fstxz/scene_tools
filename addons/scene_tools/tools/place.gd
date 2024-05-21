extends "res://addons/scene_tools/tool.gd"

# TODO: move some stuff like raycast to separate utils class

var snapping_enabled := false

var brush: Node3D

var grid_mesh: MeshInstance3D
var grid_display_enabled := true

enum Mode {
    FREE,
    PLANE,
    FILL,
}

var current_mode := Mode.FREE

var rotation := Vector3.ZERO
var snapping_step := 1.0
var snapping_offset := 0.0
var plane := Plane(Vector3.UP, 0.0)
var plane_normal: int = 0
var align_to_surface := false
var base_scale := 1.0
var random_scale := 0.0
var chance_to_spawn: int = 100

var fill_mesh: MeshInstance3D

func enter() -> void:
    setup_grid_mesh()
    setup_fill_mesh()

func exit() -> void:
    if brush:
        brush.free()
    grid_mesh.free()
    fill_mesh.free()

func edit(object: Object) -> void:
    set_root_node(object)

func handles(object: Object) -> bool:
    return object is Node

func set_root_node(node: Node) -> void:
    if node == null or not plugin.plugin_enabled:
        if grid_mesh:
            grid_mesh.hide()
        if brush:
            brush.hide()
    else:
        if not plugin.selected_asset_uids.is_empty():
            if snapping_enabled:
                set_grid_visible(grid_display_enabled)
            if brush:
                brush.show()
    plugin.root_node = node

func set_grid_visible(visible: bool) -> void:
    if plugin.plugin_enabled:
        if plugin.root_node and not plugin.selected_asset_uids.is_empty():
            if current_mode == Mode.PLANE or current_mode == Mode.FILL:
                grid_mesh.set_visible(visible)

var fill_bounding_box: AABB

func forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
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

    if event is InputEventKey:
        if event.keycode == KEY_R and event.is_pressed():
            rotation.y = wrapf(rotation.y + (PI / 4.0), 0.0, TAU)
            return EditorPlugin.AFTER_GUI_INPUT_STOP

    if event is InputEventMouseButton:
        match event.button_index:
            MOUSE_BUTTON_LEFT:
                if current_mode != Mode.FILL:
                    if event.is_pressed():
                        var asset_uid: String = plugin.selected_asset_uids.pick_random()
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
                    var node_to_erase := visual_raycast(viewport_camera)
                    if node_to_erase:
                        erase(node_to_erase)
                        return EditorPlugin.AFTER_GUI_INPUT_STOP
            
            MOUSE_BUTTON_WHEEL_DOWN:
                if Input.is_key_pressed(KEY_CTRL):
                    if event.is_pressed():
                        plane.d -= snapping_step
                        plugin.gui_instance.plane_level.text = str(plane.d)
                    return EditorPlugin.AFTER_GUI_INPUT_STOP
            
            MOUSE_BUTTON_WHEEL_UP:
                if Input.is_key_pressed(KEY_CTRL):
                    if event.is_pressed():
                        plane.d += snapping_step
                        plugin.gui_instance.plane_level.text = str(plane.d)
                    return EditorPlugin.AFTER_GUI_INPUT_STOP

    return EditorPlugin.AFTER_GUI_INPUT_PASS

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

func visual_raycast(camera: Camera3D) -> Node:
    var mousepos := EditorInterface.get_editor_viewport_3d().get_mouse_position()

    var origin := camera.project_ray_origin(mousepos)
    var end := origin + camera.project_ray_normal(mousepos) * 1000.0

    var result := RenderingServer.instances_cull_ray(origin, end, camera.get_world_3d().scenario)

    if not result.is_empty():
        # instances_cull_ray returns nodes in random order, so we have to find closest to the camera
        var closest_node: Node3D
        var closest_distance := 1000.0
        for id: int in result:
            var instance := instance_from_id(id)
            if instance.owner and instance.owner != brush:
                if (instance is MeshInstance3D
                or instance is CSGShape3D
                or instance is MultiMeshInstance3D
                or instance is Label3D
                or instance is SpriteBase3D
                or instance is Decal):
                    if instance.owner != plugin.scene_root:
                        var distance: float = instance.global_position.distance_to(camera.global_position)
                        if instance.global_position.distance_to(camera.global_position) < closest_distance:
                            closest_node = instance.owner
                            closest_distance = distance
                    elif not instance.scene_file_path.is_empty():
                        var distance: float = instance.global_position.distance_to(camera.global_position)
                        if instance.global_position.distance_to(camera.global_position) < closest_distance:
                            closest_node = instance
                            closest_distance = distance
        return closest_node
    return null

# # TODO: rework
# # taken from https://github.com/godotengine/godot/issues/85903#issuecomment-1846245217
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
                    var asset_uid: String = plugin.selected_asset_uids.pick_random()
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
        plugin.undo_redo.create_action("Fill Assets", UndoRedo.MERGE_DISABLE, plugin.scene_root)
        for asset_instance in asset_instances:
            if asset_instance:
                plugin.undo_redo.add_do_method(plugin.root_node, "add_child", asset_instance)
                plugin.undo_redo.add_do_property(asset_instance, "owner", plugin.scene_root)
                plugin.undo_redo.add_do_reference(asset_instance)
                plugin.undo_redo.add_undo_method(plugin.root_node, "remove_child", asset_instance)
        
        plugin.undo_redo.commit_action()

        # We can't apply global position before committing action, so we do it here instead.
        for asset_instance in asset_instances:
            if asset_instance:
                asset_instance.global_position = asset_instance.position
                asset_instance.global_rotation = asset_instance.rotation

func erase(node: Node) -> void:
    var parent := node.get_parent()
    plugin.undo_redo.create_action("Erase node", UndoRedo.MERGE_DISABLE, plugin.scene_root)
    plugin.undo_redo.add_do_method(parent, "remove_child", node)
    plugin.undo_redo.add_undo_method(parent, "add_child", node)
    plugin.undo_redo.add_undo_property(node, "owner", plugin.scene_root)
    plugin.undo_redo.add_undo_reference(node)
    plugin.undo_redo.commit_action()

func place_asset(asset_uid: String, position: Vector3) -> void:
    var asset_instance := instantiate_asset(asset_uid)

    if asset_instance:
        plugin.undo_redo.create_action("Place Asset", UndoRedo.MERGE_DISABLE, plugin.scene_root)
        plugin.undo_redo.add_do_method(plugin.root_node, "add_child", asset_instance)
        plugin.undo_redo.add_do_property(asset_instance, "owner", plugin.scene_root)
        plugin.undo_redo.add_do_reference(asset_instance)
        plugin.undo_redo.add_undo_method(plugin.root_node, "remove_child", asset_instance)
        plugin.undo_redo.commit_action()

        asset_instance.global_position = position
        asset_instance.global_rotation = brush.rotation

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

func setup_grid_mesh() -> void:
    grid_mesh = MeshInstance3D.new()
    grid_mesh.mesh = PlaneMesh.new()
    var shader_material := ShaderMaterial.new()
    shader_material.shader = preload("res://addons/scene_tools/grid.gdshader")
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
    plugin.add_child(fill_mesh)

func set_snapping_step(value: float) -> void:
    snapping_step = maxf(0.1, value)
    grid_mesh.mesh.surface_get_material(0).set_shader_parameter("grid_step", snapping_step)

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

func load_state(configuration: ConfigFile) -> void:
    change_mode(configuration.get_value(plugin.plugin_name, "current_mode", current_mode))

    snapping_enabled = configuration.get_value(plugin.plugin_name, "snapping_enabled", false)
    plugin.gui_instance.snapping_button.set_pressed_no_signal(snapping_enabled)

    plane.d = configuration.get_value(plugin.plugin_name, "plane_level", 0.0)
    plugin.gui_instance.plane_level.text = str(plane.d)

    set_snapping_step(configuration.get_value(plugin.plugin_name, "snapping_step", 1.0))
    plugin.gui_instance.snapping_step.text = str(snapping_step)

    snapping_offset = configuration.get_value(plugin.plugin_name, "snapping_offset", 0.0)
    plugin.gui_instance.snapping_offset.text = str(snapping_offset)

    align_to_surface = configuration.get_value(plugin.plugin_name, "align_to_surface", false)
    plugin.gui_instance.align_to_surface_button.set_pressed_no_signal(align_to_surface)

    base_scale = configuration.get_value(plugin.plugin_name, "base_scale", 1.0)
    plugin.gui_instance.base_scale.text = str(base_scale)

    random_scale = configuration.get_value(plugin.plugin_name, "random_scale", 0.0)
    plugin.gui_instance.random_scale.text = str(random_scale)

    plane_normal = configuration.get_value(plugin.plugin_name, "plane_normal", 0)
    plugin.gui_instance.plane_option.selected = plane_normal
    set_plane_normal(plane_normal)

    grid_display_enabled = configuration.get_value(plugin.plugin_name, "grid_display_enabled", true)
    plugin.gui_instance.display_grid_checkbox.set_pressed_no_signal(grid_display_enabled)

    chance_to_spawn = configuration.get_value(plugin.plugin_name, "chance_to_spawn", chance_to_spawn)
    plugin.gui_instance.chance_to_spawn.text = str(chance_to_spawn)

func save_state(configuration: ConfigFile) -> void:
    configuration.set_value(plugin.plugin_name, "snapping_enabled", snapping_enabled)
    configuration.set_value(plugin.plugin_name, "plane_level", plane.d)
    configuration.set_value(plugin.plugin_name, "snapping_step", snapping_step)
    configuration.set_value(plugin.plugin_name, "snapping_offset", snapping_offset)
    configuration.set_value(plugin.plugin_name, "align_to_surface", align_to_surface)
    configuration.set_value(plugin.plugin_name, "base_scale", base_scale)
    configuration.set_value(plugin.plugin_name, "random_scale", random_scale)
    configuration.set_value(plugin.plugin_name, "plane_normal", plane_normal)
    configuration.set_value(plugin.plugin_name, "grid_display_enabled", grid_display_enabled)
    configuration.set_value(plugin.plugin_name, "chance_to_spawn", chance_to_spawn)
    configuration.set_value(plugin.plugin_name, "current_mode", current_mode)

func set_snapping_enabled(enabled: bool) -> void:
    snapping_enabled = enabled
    if grid_display_enabled:
        set_grid_visible(enabled)

func set_grid_display_enabled(enabled: bool) -> void:
    grid_display_enabled = enabled
    if snapping_enabled:
        set_grid_visible(enabled)

func set_plane_level(value: float) -> void:
    plane.d = value

func set_snapping_offset(value: float) -> void:
    snapping_offset = value

func set_base_scale(value: float) -> void:
    base_scale = value
    if brush:
        brush.scale = Vector3(base_scale, base_scale, base_scale)

func set_random_scale(value: float) -> void:
    random_scale = value

func set_chance_to_spawn(value: int) -> void:
    chance_to_spawn = clampi(value, 0, 100)

func set_align_to_surface(value: bool) -> void:
    align_to_surface = value

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

        if plugin.scene_root:
            plugin.scene_root.add_child(brush)
        else:
            _on_scene_changed(EditorInterface.get_edited_scene_root())

        if not plugin.root_node or not plugin.plugin_enabled:
            brush.hide()

func change_mode(new_mode: Mode) -> void:
    # Mode exiting logic
    match current_mode:
        Mode.FREE:
            plugin.gui_instance.surface_container.hide()
        Mode.PLANE:
            plugin.gui_instance.plane_container.hide()
            set_grid_visible(false)
        Mode.FILL:
            plugin.gui_instance.plane_container.hide()
            plugin.gui_instance.chance_to_spawn_container.hide()
            set_grid_visible(false)

    current_mode = new_mode
    plugin.gui_instance.mode_option.selected = current_mode

    # Mode entering logic
    match current_mode:
        Mode.FREE:
            plugin.gui_instance.surface_container.show()
        Mode.PLANE:
            plugin.gui_instance.plane_container.show()
            if snapping_enabled:
                set_grid_visible(grid_display_enabled)
        Mode.FILL:
            plugin.gui_instance.plane_container.show()
            plugin.gui_instance.chance_to_spawn_container.show()
            if snapping_enabled:
                set_grid_visible(grid_display_enabled)

func _on_scene_changed(scene_root: Node) -> void:
    if is_instance_valid(plugin.scene_root):
        if is_instance_valid(brush):
            self.scene_root.remove_child(brush)
        if is_instance_valid(grid_mesh):
            self.scene_root.remove_child(grid_mesh)

    plugin.scene_root = scene_root

    if is_instance_valid(plugin.scene_root):
        if is_instance_valid(brush):
            plugin.scene_root.add_child(brush)
        if is_instance_valid(grid_mesh):
            plugin.scene_root.add_child(grid_mesh)

func on_scene_closed(path: String) -> void:
    if plugin.scene_root and plugin.scene_root.scene_file_path == path:
        if is_instance_valid(brush):
            plugin.scene_root.remove_child(brush)
        if is_instance_valid(grid_mesh):
            plugin.scene_root.remove_child(grid_mesh)
