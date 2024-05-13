shader_type spatial;
render_mode cull_disabled;

uniform float line_width = 0.01;
uniform float grid_step = 1.0;
const float grid_size = 16.0;
uniform vec4 line_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 fill_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec3 mouse_world_position;

void vertex() {
    VERTEX = VERTEX * grid_step * grid_size;
}

void fragment() {
    vec2 centered_uv = ((UV * 2.0) - 1.0) * grid_step * grid_size;
	vec2 lineUV = abs(mod(centered_uv + grid_step, grid_step) / grid_step - 0.5) * 2.0;
    vec2 line = smoothstep(line_width, line_width, lineUV);
    float grid = line.x * line.y;

    vec3 world_position = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float fade = smoothstep(grid_step * 4.0, 0.0, distance(world_position, mouse_world_position));

    ALBEDO = mix(line_color.rgb, fill_color.rgb, grid);
    ALPHA = mix(line_color.a, fill_color.a, grid) * fade;
}
