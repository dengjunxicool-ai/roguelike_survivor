shader_type canvas_item;
render_mode unshaded;
uniform float visual_clock = 0.0;
uniform float attack_light : hint_range(0.0, 1.0) = 0.0;
varying vec2 scale_position;
void vertex() { scale_position = VERTEX; }
void fragment() {
	vec4 scale_color = COLOR;
	vec2 cell = floor(scale_position * vec2(0.26, 0.35));
	float seams = pow(max(0.0, sin(scale_position.y * 0.72 + sin(cell.y) * 1.8) * sin(scale_position.x * 0.46)), 10.0);
	float heat = 0.5 + 0.5 * sin(visual_clock * 2.8 + cell.x * 0.6 + cell.y * 0.8);
	vec3 molten = vec3(1.0, 0.63, 0.12);
	COLOR = vec4(mix(scale_color.rgb, molten, seams * (0.2 + heat * 0.2) + attack_light * 0.26), scale_color.a);
}
