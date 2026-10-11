shader_type canvas_item;
render_mode unshaded;
uniform float visual_clock = 0.0;
uniform float attack_light : hint_range(0.0,1.0) = 0.0;
varying vec2 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	vec4 base = COLOR;
	float pulse = 0.5 + 0.5*sin(visual_clock*5.2 + local_position.x*0.17 - local_position.y*0.21);
	float rim = pow(max(0.0,sin(local_position.y*0.62+local_position.x*0.27)),12.0);
	vec3 electric = vec3(0.54,0.88,1.0);
	COLOR = vec4(mix(base.rgb,electric,rim*0.09*pulse+attack_light*0.35),base.a);
}
