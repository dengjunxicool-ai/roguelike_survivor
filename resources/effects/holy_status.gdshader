shader_type canvas_item;
render_mode unshaded;
uniform float effect_age=0.0;
uniform float stacks=1.0;
uniform int profile=0;
uniform float shield_fraction=0.0;
uniform float countdown=1.0;
varying vec2 point;
void vertex(){point=VERTEX;}
float line(vec2 p,vec2 a,vec2 b){vec2 d=b-a;return exp(-length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0))*110.0);}
void fragment(){
	vec2 p=vec2(point.x/48.0,(point.y+26.0)/53.0);
	vec2 floor_p=vec2(p.x,(p.y-0.62)*3.2);
	float r=length(floor_p),a=atan(floor_p.y,floor_p.x),age=effect_age;
	float runes=pow(max(cos(a*12.0+age*0.22),0.0),16.0);
	float gold=exp(-abs(r-0.74)*95.0)*(0.22+0.48*runes),white=0.0;
	if(profile==0){
		for(int i=0;i<5;i++){
			vec2 q=p-vec2((float(i)-2.0)*0.19,-0.67-0.035*cos(float(i)-2.0));
			float diamond=abs(q.x)+abs(q.y);
			white=max(white,exp(-abs(diamond-0.058)*170.0)*step(float(i)+0.5,stacks));
		}
		vec2 q=p-vec2(0.0,-0.40);
		gold=max(gold,line(q,vec2(0,-0.10),vec2(0,0.15))*0.6);
		gold=max(gold,line(q,vec2(-0.22,0),vec2(0.22,0))*0.6);
		gold=max(gold,exp(-abs(length(vec2(abs(q.x)-0.17,q.y-0.03))-0.075)*100.0)*step(0.0,q.y)*0.5);
	}else if(profile==1){
		vec2 q=vec2(p.x*1.12,(p.y+0.11)*0.82);
		float angle=atan(q.y,q.x),edge=0.72/(cos(mod(angle+0.2618,0.5236)-0.2618));
		float shell=exp(-abs(length(q)-edge)*80.0);
		white=shell*(0.26+0.54*sqrt(shield_fraction));
		gold=max(gold,shell*pow(max(cos(angle*12.0-age*0.3),0.0),20.0)*0.85);
		gold=max(gold,exp(-abs(r-0.84)*100.0)*step(fract((a+3.14159)/6.28318),shield_fraction)*0.72);
	}else if(profile==2){
		float fill=step(fract((a+3.14159)/6.28318),countdown);
		gold=max(gold,exp(-abs(r-0.91)*95.0)*fill*0.8);
		vec2 q=p-vec2(0,-0.70);
		white=exp(-abs(length(vec2(q.x,q.y*2.8))-0.28)*130.0)*0.85;
		for(int i=0;i<6;i++){
			float f=float(i),x=(f-2.5)*0.24;
			vec2 feather=p-vec2(x,0.38-fract(age*0.24+f*0.16)*0.9);
			gold=max(gold,exp(-abs(feather.x+feather.y*0.25)*130.0)*(1.0-smoothstep(0.035,0.13,abs(feather.y)))*0.5);
		}
	}else{
		gold*=step(0.1,cos(a*3.0));
		vec2 q=p-vec2(0,-0.56);
		white=max(line(q,vec2(-0.14,-0.04),vec2(0,0.13)),line(q,vec2(0,0.13),vec2(0.14,-0.04)))*0.6;
	}
	vec3 color=mix(vec3(0.84,0.62,0.24),vec3(1.0,0.97,0.85),white/(gold+white+0.001));
	COLOR=vec4(color,clamp(max(gold,white)*(0.90+0.05*sin(age*3.0)),0.0,0.9));
}
