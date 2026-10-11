shader_type canvas_item;
render_mode unshaded;
uniform float visual_clock = 0.0;
uniform float confirmed_pulse = 0.0;
void fragment() {
	vec4 ink = COLOR;
	float fracture = step(0.84, fract(UV.y * 9.0 + UV.x * 3.0));
	float breathe = 0.94 + 0.06 * sin(visual_clock * 3.1 + UV.y * 6.0);
	ink.rgb *= breathe;
	ink.rgb += vec3(0.13, 0.31, 0.34) * confirmed_pulse * ink.a;
	ink.a *= 1.0 - fracture * 0.12;
	COLOR = ink;
}
