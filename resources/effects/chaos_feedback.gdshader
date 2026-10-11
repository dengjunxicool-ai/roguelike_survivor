shader_type canvas_item;
render_mode unshaded;
uniform float progress=0.0;
uniform int profile=0;
uniform float seed=0.0;
varying vec2 point;
void vertex(){point=VERTEX;}
void fragment(){
 vec2 p=point;float t=progress,r=length(p),a=atan(p.y,p.x),white=0.0,purple=0.0;
 if(profile==2){
  float kink=sin(p.x*13.0+seed)*sin(p.x*19.0-seed)*0.13*sin((p.x+1.0)*1.5708);
  float distance_to_tear=abs(p.y-kink);
  white=exp(-distance_to_tear*90.0)*0.9;
  purple=exp(-distance_to_tear*14.0)*0.55;
  white=max(white,exp(-length(vec2((abs(p.x)-0.95)*9.0,p.y))*14.0));
 }else{
  float edge=abs(p.x)+abs(p.y)*(profile==1?0.75:1.0);
  purple=exp(-abs(edge-(0.16+t*0.75))*65.0)*pow(abs(cos(a*4.0+seed)),4.0);
  white=exp(-r*23.0)*(1.0-t);
  if(profile==1){white=max(white,exp(-abs(edge-0.42)*100.0)*0.8);}
  else{white=max(white,exp(-abs(p.x+p.y*0.6)*100.0)*(1.0-smoothstep(0.12,0.55,r)));}
 }
 COLOR=vec4(mix(vec3(0.72,0.13,1.0),vec3(0.76,1.0,1.0),white/(purple+white+0.001)),clamp(max(white,purple)*pow(1.0-t,1.4),0.0,1.0));
}
