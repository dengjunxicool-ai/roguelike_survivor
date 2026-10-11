## 真实失稳层数与被动进度的只读光纹；状态宿主控制期限。
extends Node2D
const EffectShader=preload("res://resources/effects/chaos_status.gdshader")
var status_stacks:=0
var visual_age:=0.0
var remaining:=-1.0
var profile:=0
var _duration_paused:=false
var _host_controls_lifetime:=false
var _material: ShaderMaterial
func _init() -> void:
	visible=false;set_process(false)
func _ready() -> void: _ensure_visuals()
func _ensure_visuals() -> void:
	if _material!=null: return
	var surface:=Polygon2D.new();surface.name="FracturedState"
	surface.polygon=PackedVector2Array([Vector2(-56,-86),Vector2(56,-86),Vector2(56,30),Vector2(-56,30)])
	_material=ShaderMaterial.new();_material.shader=EffectShader;surface.material=_material;add_child(surface)
func configure_status(snapshot: Dictionary) -> void:
	_ensure_visuals()
	var next_profile:=int({"instability":0,"entropy":1,"stability":2,"echo":3,"singularity":4}.get(String(snapshot.get("status_id","instability")),0))
	if not visible or next_profile!=profile: visual_age=0.0
	profile=next_profile;status_stacks=clampi(int(snapshot.get("stacks",1)),1,4)
	remaining=float(snapshot.get("duration_remaining",-1.0))
	_duration_paused=bool(snapshot.get("duration_paused",false));_host_controls_lifetime=bool(snapshot.get("host_controls_lifetime",false))
	_material.set_shader_parameter("stacks",float(status_stacks));_material.set_shader_parameter("profile",profile)
	_material.set_shader_parameter("branch",clampi(int(snapshot.get("branch",0)),0,3))
	_material.set_shader_parameter("charge_fraction",clampf(float(snapshot.get("charge_fraction",0.0)),0.0,1.0))
	_material.set_shader_parameter("ready",bool(snapshot.get("ready",false)))
	_material.set_shader_parameter("countdown",clampf(remaining/5.0,0.0,1.0))
	_material.set_shader_parameter("effect_age",visual_age);visible=true;set_process(true)
func _process(delta: float) -> void:
	visual_age+=maxf(delta,0.0);_material.set_shader_parameter("effect_age",visual_age)
	if remaining>=0.0 and not _duration_paused:
		remaining=maxf(remaining-maxf(delta,0.0),0.0)
		_material.set_shader_parameter("countdown",clampf(remaining/5.0,0.0,1.0))
		if remaining<=0.0 and not _host_controls_lifetime: deactivate()
func deactivate() -> void:
	visible=false;set_process(false)
