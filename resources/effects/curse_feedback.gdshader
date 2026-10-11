shader_type canvas_item;
render_mode unshaded;
uniform float progress=0.0;
uniform float seed=0.0;
uniform int profile=0;
varying vec2 p;
void vertex(){p=VERTEX;}
void fragment(){
	float r=length(p),a=atan(p.y,p.x)+seed;
	float fade=(1.0-smoothstep(0.45,1.0,progress))*smoothstep(0.0,0.04,progress);
	float wave=exp(-abs(r-(0.18+progress*0.68))*70.0);
	float spokes=pow(max(0.0,cos(a*(profile==1?8.0:5.0)+progress*2.0)),24.0);
	float sigil=exp(-abs(r-0.36)*100.0)*(0.35+spokes*0.65);
	float core=exp(-r*18.0)*(1.0-progress);
	float soul=wave*0.65+core;
	float alpha=(wave*0.48+sigil*(1.0-progress)+spokes*exp(-abs(r-progress*0.85)*25.0)*0.55)*fade;
	vec3 color=mix(vec3(0.48,0.12,0.66),vec3(0.72,1.0,0.79),clamp(soul,0.0,1.0));
	if(profile==2){
		float cross=min(abs(p.x),abs(p.y));
		alpha=max(alpha*0.5,exp(-cross*95.0)*(1.0-smoothstep(0.28,0.43,max(abs(p.x),abs(p.y))))*fade);
		color=vec3(0.48,0.98,0.68);
	}
	COLOR=vec4(color,alpha)*COLOR;
}
