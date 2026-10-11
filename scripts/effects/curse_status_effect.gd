## 只读咒印与真实蓄能，独立材质、固定几何、暂停随场景时钟。
extends Node2D
const EffectShader = preload("res://resources/effects/curse_status.gdshader")
var status_stacks := 0
var visual_age := 0.0
var remaining := -1.0
var profile := 0
var _duration_paused := false
var _host_controls_lifetime := false
var _material: ShaderMaterial
func _init() -> void:
	visible=false
	set_process(false)
func _ready() -> void: _ensure_visuals()
func _ensure_visuals() -> void:
	if _material!=null: return
	var surface:=Polygon2D.new()
	surface.name="SoulSeal"
	surface.polygon=PackedVector2Array([Vector2(-44,-72),Vector2(44,-72),Vector2(44,24),Vector2(-44,24)])
	_material=ShaderMaterial.new()
	_material.shader=EffectShader
	surface.material=_material
	add_child(surface)
func configure_status(snapshot: Dictionary) -> void:
	_ensure_visuals()
	var id:=String(snapshot.get("status_id","cursed"))
	var next_profile:=1 if id=="death_pact" else (2 if id in ["harvest_ready","harvest_charge"] else (3 if id=="soul_debt" else 0))
	if not visible or next_profile!=profile: visual_age=0.0
	profile=next_profile
	status_stacks=clampi(int(snapshot.get("stacks",1)),1,3)
	remaining=float(snapshot.get("duration_remaining",-1.0))
	_duration_paused=bool(snapshot.get("duration_paused",false))
	_host_controls_lifetime=bool(snapshot.get("host_controls_lifetime",false))
	_material.set_shader_parameter("stacks",float(status_stacks))
	_material.set_shader_parameter("profile",profile)
	_material.set_shader_parameter("charge_fraction",clampf(float(snapshot.get("charge_fraction",1.0)),0.0,1.0))
	_material.set_shader_parameter("ready",id=="harvest_ready")
	_material.set_shader_parameter("countdown",clampf(remaining/5.0,0.0,1.0) if profile==1 else 1.0)
	_material.set_shader_parameter("effect_age",visual_age)
	visible=true
	set_process(true)
func _process(delta: float) -> void:
	visual_age+=delta
	_material.set_shader_parameter("effect_age",visual_age)
	if remaining>=0.0 and not _duration_paused:
		remaining=maxf(remaining-delta,0.0)
		if profile==1: _material.set_shader_parameter("countdown",clampf(remaining/5.0,0.0,1.0))
		if remaining<=0.0 and not _host_controls_lifetime: deactivate()
func deactivate() -> void:
	visible=false
	set_process(false)
