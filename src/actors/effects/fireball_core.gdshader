// Story 7-1 (AC 16): the Fireball's GLOWING CORE -- "a glowing core with moving noise". No texture: the noise
// is a cheap value-noise of the surface position scrolled by TIME, so the surface churns while the ball flies.
// Unshaded and emissive; the core's SIZE is the mesh's (the presenter scales it from mana invested, inside the
// 0.35 m hit sphere -- AC 17), and nothing here moves a vertex, so the solid core never reads larger than it is.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 hot_color : source_color = vec4(1.0, 0.9, 0.55, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.35, 0.05, 1.0);
uniform float energy = 3.0;
uniform float churn_speed = 1.6;
uniform float churn_scale = 9.0;

varying vec3 local_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 p = normalize(local_pos) * churn_scale + vec3(0.0, -TIME * churn_speed, TIME * 0.7);
	float n = value_noise(p) * 0.65 + value_noise(p * 2.1) * 0.35;
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 col = mix(hot_color.rgb, edge_color.rgb, clamp(n * 0.9 + rim * 0.6, 0.0, 1.0));
	ALBEDO = col * energy;
}
