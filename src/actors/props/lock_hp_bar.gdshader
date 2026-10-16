// 7-7 pre-playtest pass: the locked-unit HP bar -- one camera-facing quad. A dark frame, the filled part in the
// locking player's tint, the rest a dark back. Drawn over the world (no depth test) so the bar is never hidden in
// the unit's own body. Billboarded in the vertex stage, so each SubViewport camera sees it face-on.
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled;

uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 back_color : source_color = vec4(0.06, 0.05, 0.05, 0.8);
uniform vec4 frame_color : source_color = vec4(0.0, 0.0, 0.0, 0.95);
uniform float fraction : hint_range(0.0, 1.0) = 1.0;
// The frame's thickness in UV, per axis (the quad is wide and short, so x is thinner).
uniform vec2 frame_uv = vec2(0.025, 0.18);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 color = frame_color;
	if (UV.x > frame_uv.x && UV.x < 1.0 - frame_uv.x && UV.y > frame_uv.y && UV.y < 1.0 - frame_uv.y) {
		float along = (UV.x - frame_uv.x) / (1.0 - 2.0 * frame_uv.x);
		color = along <= fraction ? fill_color : back_color;
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
