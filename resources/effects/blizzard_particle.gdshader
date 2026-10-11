shader_type canvas_item;
render_mode unshaded;

uniform int particle_style = 0;
varying vec4 particle_color;

void vertex() {
	particle_color = COLOR;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float shape;
	if (particle_style == 0) {
		// Six small crystal arms and a bright center, softened at subpixel edges.
		float a = atan(p.y, p.x);
		float r = length(p);
		float arms = pow(abs(cos(a * 3.0)), 12.0) * (1.0 - smoothstep(0.15, 0.85, r));
		shape = max(arms, 1.0 - smoothstep(0.08, 0.3, r));
	} else if (particle_style == 1) {
		shape = 1.0 - smoothstep(0.3, 0.8, abs(p.x) * 2.0 + abs(p.y) * 0.65);
	} else {
		float r = length(p);
		float glint = (1.0 - smoothstep(0.02, 0.18, min(abs(p.x), abs(p.y))))
			* (1.0 - smoothstep(0.2, 0.9, r));
		shape = max(glint, (1.0 - smoothstep(0.0, 0.65, r)) * 0.3);
	}
	COLOR = vec4(particle_color.rgb, particle_color.a * shape);
}
