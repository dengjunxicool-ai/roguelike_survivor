shader_type canvas_item;
render_mode unshaded;

uniform float visual_clock = 0.0;
uniform float attack_light : hint_range(0.0, 1.0) = 0.0;
varying vec2 ice_position;

void vertex() {
	ice_position = VERTEX;
}

void fragment() {
	vec4 facet = COLOR;
	float grain = fract(sin(dot(floor(ice_position * 2.4), vec2(17.37, 63.19))) * 43758.54);
	float striation = pow(max(0.0, sin(ice_position.x * 0.44 + ice_position.y * 0.71)), 22.0);
	float glint = pow(max(0.0, sin(ice_position.x * 0.12 + ice_position.y * 0.06 - visual_clock * 1.6)), 18.0);
	vec3 white = vec3(0.83, 0.97, 1.0);
	COLOR = vec4(mix(facet.rgb, white, striation * 0.16 + glint * 0.13 + attack_light * 0.38) + grain * 0.025, facet.a);
}
