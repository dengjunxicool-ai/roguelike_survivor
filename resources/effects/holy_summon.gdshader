shader_type canvas_item;
render_mode unshaded;
uniform float visual_clock = 0.0;
uniform float launch_light : hint_range(0.0, 1.0) = 0.0;
varying vec2 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	vec4 base = COLOR;
	float shimmer = pow(max(0.0, sin(local_position.y * 0.25 + local_position.x * 0.12 - visual_clock * 2.0)), 10.0);
	float pulse = 0.5 + 0.5 * sin(visual_clock * 3.7 + local_position.y * 0.13);
	vec3 pearl = vec3(1.0, 0.94, 0.72);
	COLOR = vec4(mix(base.rgb, pearl, shimmer * pulse * 0.11 + launch_light * 0.22), base.a);
}
