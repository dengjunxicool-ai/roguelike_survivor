shader_type canvas_item;
render_mode unshaded;
uniform float visual_clock = 0.0;
uniform float attack_light : hint_range(0.0,1.0) = 0.0;
varying vec2 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	vec4 base = COLOR;
	float wave = 0.5+0.5*sin(visual_clock*3.4+local_position.y*0.14);
	float soul = step(base.r*1.45,base.g);
	vec3 tint = mix(vec3(0.31,0.12,0.43),vec3(0.58,1.0,0.66),soul);
	COLOR = vec4(mix(base.rgb,tint,soul*wave*0.13+attack_light*0.16),base.a);
}
