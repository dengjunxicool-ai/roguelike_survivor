shader_type canvas_item;
render_mode unshaded;
uniform float progress=0.0;
uniform int profile=0;
uniform float seed=0.0;
varying vec2 point;
void vertex(){point=VERTEX;}
void fragment(){
	vec2 p=point;float t=progress,r=length(p),a=atan(p.y,p.x);
	float fade=pow(1.0-t,1.4),ring=exp(-abs(r-(0.18+t*0.70))*55.0),white=0.0,gold=0.0;
	if(profile==1){
		float gate=smoothstep(-5.0,-4.6,p.y)*(1.0-smoothstep(0.0,0.5,p.y));
		white=exp(-abs(p.x)*34.0)*gate*(1.0-t);
		gold=exp(-abs(p.x)*9.0)*gate*0.38;
		gold=max(gold,ring*(0.4+pow(max(cos(a*8.0),0.0),10.0)*0.6));
	}else if(p.y>=-1.0){
		gold=ring*(0.4+pow(abs(cos(a*6.0+seed)),18.0)*0.6);
		white=exp(-r*18.0)*(1.0-t);
		if(profile==2){
			gold=max(gold,exp(-abs(max(abs(p.x)*0.85,abs(p.y))-0.42-t*0.18)*70.0)*0.7);
		}else if(profile==3){
			gold*=pow(abs(cos(a*8.0-seed)),8.0);
		}else{
			white=max(white,exp(-abs(p.x)*85.0)*(1.0-smoothstep(0.1,0.7,abs(p.y)))*0.8);
			white=max(white,exp(-abs(p.y)*85.0)*(1.0-smoothstep(0.1,0.7,abs(p.x)))*0.65);
		}
	}
	COLOR=vec4(mix(vec3(0.93,0.67,0.25),vec3(1.0,0.98,0.88),white/(gold+white+0.001)),clamp(max(white,gold)*fade,0.0,1.0));
}
