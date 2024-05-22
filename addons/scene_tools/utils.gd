static func raycast(camera: Camera3D) -> Dictionary:
    var space_state := camera.get_world_3d().direct_space_state
    var mousepos := EditorInterface.get_editor_viewport_3d().get_mouse_position()

    var origin := camera.project_ray_origin(mousepos)
    var end := origin + camera.project_ray_normal(mousepos) * 1000.0
    var query := PhysicsRayQueryParameters3D.create(origin, end)

    return space_state.intersect_ray(query)

static func raycast_plane(camera: Camera3D, plane: Plane) -> Variant:
    var mousepos := EditorInterface.get_editor_viewport_3d().get_mouse_position()
    return plane.intersects_ray(camera.project_ray_origin(mousepos), camera.project_ray_normal(mousepos) * 1000.0)
