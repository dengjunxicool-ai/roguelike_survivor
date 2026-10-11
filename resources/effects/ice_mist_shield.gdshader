shader_type canvas_item;
render_mode unshaded;
uniform float effect_age=0.0;
uniform float layers=1.0;
uniform float strength=1.0;
varying vec2 plane_position;
void vertex(){ plane_position=VERTEX; }
void fragment(){
	vec2 p=vec2(plane_position.x/44.0,(plane_position.y+16.0)/40.0);
	float r=length(p);
	float angle=atan(p.y,p.x);
	float ribbon=0.0;
	for(int i=0;i<3;i++){
		float n=float(i);
		if(n<layers){
			float radius=0.74+n*0.045+sin(angle*4.0-effect_age*1.5+n)*0.018;
			float ring=exp(-abs(r-radius)*45.0);
			float flow=0.3+0.7*pow(0.5+0.5*sin(angle*3.0+effect_age*1.3+n*2.1),3.0);
			ribbon+=ring*flow;
		}
	}
	float mist=exp(-abs(r-0.72)*12.0)*(0.035+0.025*sin(angle*7.0-effect_age));
	float alpha=(ribbon*0.5+mist)*(0.45+0.55*strength);
	COLOR=vec4(mix(vec3(0.27,0.65,0.9),vec3(0.82,0.98,1),ribbon),clamp(alpha,0.0,0.7))*COLOR;
}
