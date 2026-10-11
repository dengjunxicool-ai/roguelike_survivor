## 感电层数与蓄能光环只读表现；固定四边形，时钟随场景暂停。
extends Node2D
const EffectShader = preload("res://resources/effects/thunder_status.gdshader")
var status_stacks := 0
var visual_age := 0.0
var _material: ShaderMaterial
func _ready() -> void:
	_ensure_visuals()
func _ensure_visuals() -> void:
	if _material != null: return
	var surface := Polygon2D.new()
	surface.name = "ElectricMantle"
	surface.polygon = PackedVector2Array([Vector2(-40,-68),Vector2(40,-68),Vector2(40,20),Vector2(-40,20)])
	_material = ShaderMaterial.new()
	_material.shader = EffectShader
	surface.material = _material
	add_child(surface)
func configure_status(snapshot: Dictionary) -> void:
	_ensure_visuals()
	if not visible: visual_age = 0.0
	status_stacks = clampi(int(snapshot.get("stacks",1)),1,5)
	_material.set_shader_parameter("stacks",float(status_stacks))
	_material.set_shader_parameter("charged",String(snapshot.get("status_id",""))=="static_charge")
	_material.set_shader_parameter("core_charge",String(snapshot.get("status_id",""))=="storm_charge")
	_material.set_shader_parameter("charge_fraction",clampf(float(snapshot.get("charge_fraction",1.0)),0.0,1.0))
	_material.set_shader_parameter("effect_age",visual_age)
	visible = true
	set_process(true)
func _process(delta: float) -> void:
	visual_age += delta
	_material.set_shader_parameter("effect_age",visual_age)
func deactivate() -> void:
	visible = false
	set_process(false)
