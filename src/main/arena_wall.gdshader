// 7-7 pre-playtest pass: the arena WALLS' subtle tiled reference on the 5-0d glass. The glass colour and its 0.35
// alpha are the old `StandardMaterial3D_wallglass` values unchanged, so the camera still sees through every wall;
// a faint 1 m grid (slightly darker, a touch more opaque on the line only) marks distance along the wall. The walls
// are axis-aligned, so x + z runs along every wall and y up it. Lines fade where a cell nears a pixel (no moire).
shader_type spatial;

uniform vec4 glass_color : source_color = vec4(0.6, 0.7, 0.85, 0.35);
uniform float tile_size = 1.0;
uniform float line_width = 0.03;
uniform float line_darken = 0.25;
uniform float line_alpha = 0.08;
uniform vec2 fade_fwidth = vec2(0.06, 0.25);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = vec2(world_pos.x + world_pos.z, world_pos.y) / tile_size;
	vec2 fw = max(fwidth(p), vec2(1e-5));
	vec2 dist = abs(fract(p - 0.5) - 0.5);
	vec2 half_width = vec2(0.5 * line_width / tile_size);
	vec2 on_line = 1.0 - smoothstep(half_width - fw, half_width + fw, dist);
	float fade = 1.0 - smoothstep(fade_fwidth.x, fade_fwidth.y, max(fw.x, fw.y));
	float line = max(on_line.x, on_line.y) * fade;
	ALBEDO = glass_color.rgb * (1.0 - line_darken * line);
	ALPHA = glass_color.a + line_alpha * line;
}
