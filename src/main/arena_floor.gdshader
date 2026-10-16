// 7-7 pre-playtest pass: the arena FLOOR's subtle tiled reference -- a faint world-space grid with an even fainter
// checker, so motion and position read against the ground without a pattern competing with the fight. Low contrast
// by construction (a few percent darker than the old plain white floor); anti-aliased lines; and the whole pattern
// fades out where a tile shrinks toward a pixel (far and grazing), which is what keeps it free of moire.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(1.0);
// Grid cell edge, in metres.
uniform float tile_size = 2.0;
// Line width, in metres.
uniform float line_width = 0.05;
// How much darker a grid line is, and an alternate checker cell, than the base.
uniform float line_darken = 0.09;
uniform float checker_darken = 0.035;
// The pattern fades between these screen-space cell sizes (fwidth of the cell coordinate).
uniform vec2 fade_fwidth = vec2(0.06, 0.25);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / tile_size;
	vec2 fw = max(fwidth(p), vec2(1e-5));
	vec2 dist = abs(fract(p - 0.5) - 0.5);
	vec2 half_width = vec2(0.5 * line_width / tile_size);
	vec2 on_line = 1.0 - smoothstep(half_width - fw, half_width + fw, dist);
	float fade = 1.0 - smoothstep(fade_fwidth.x, fade_fwidth.y, max(fw.x, fw.y));
	float line = max(on_line.x, on_line.y) * fade;
	vec2 cell = floor(p);
	float checker = mod(cell.x + cell.y, 2.0) * fade;
	ALBEDO = base_color * (1.0 - line_darken * line - checker_darken * checker);
}
