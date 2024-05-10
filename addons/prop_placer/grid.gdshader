shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float grid_step = 1.0;
uniform float line_width = 1.0;
uniform vec4 line_color = vec4(1.0);
uniform vec4 fill_color;
uniform vec3 mouse_world_position = vec3(0.0);
uniform ivec3 axis = ivec3(1, 0, 0);

void fragment() {
    vec3 world_position = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

    vec3 grid_pos = abs(mod(world_position + grid_step, grid_step) / grid_step - 0.5) * 2.0;
    float line_width_scaled = line_width * 0.005 * length(world_position - CAMERA_POSITION_WORLD) / grid_step;
    float line;
    if (axis.x == 1) {
        line = min(step(line_width_scaled, grid_pos.x), step(line_width_scaled, grid_pos.z));
    }
    else if (axis.y == 1) {
        line = min(step(line_width_scaled, grid_pos.x), step(line_width_scaled, grid_pos.y));
    }
    else {
        line = min(step(line_width_scaled, grid_pos.z), step(line_width_scaled, grid_pos.y));
    }

    float fade = smoothstep(grid_step * 4.0, 0.0, distance(world_position, mouse_world_position));
    ALBEDO = mix(line_color, fill_color, line).rgb;
    ALPHA = mix(line_color.a, fill_color.a, line) * fade;
}
