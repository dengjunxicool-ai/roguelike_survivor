## 冰雾盾表现：只接收已生成的护盾量，不能改变防护与吸收。
extends Node2D
const MistShader = preload("res://resources/effects/ice_mist_shield.gdshader")
var shield_layers := 0
var shield_fraction := 0.0
var visual_age := 0.0
var _material: ShaderMaterial

func _ready() -> void:
	var surface := Polygon2D.new()
	surface.name = "ShieldMist"
	surface.polygon = PackedVector2Array([Vector2(-44,-57),Vector2(44,-57),Vector2(44,24),Vector2(-44,24)])
	_material = ShaderMaterial.new()
	_material.shader = MistShader
	surface.material = _material
	add_child(surface)
	z_index = 18
	deactivate()

func update_shield(layers: int, fraction: float) -> void:
	shield_layers = clampi(layers,0,3)
	shield_fraction = clampf(fraction,0.0,1.0)
	visible = shield_layers > 0 and shield_fraction > 0.0
	set_process(visible)
	_material.set_shader_parameter("layers", float(shield_layers))
	_material.set_shader_parameter("strength", shield_fraction)
	queue_redraw()

func _process(delta: float) -> void:
	visual_age += delta
	_material.set_shader_parameter("effect_age",visual_age)
	queue_redraw()

func deactivate() -> void:
	shield_layers = 0
	shield_fraction = 0.0
	visible = false
	set_process(false)

func _draw() -> void:
	for index: int in shield_layers*2:
		var angle := float(index)*TAU/(shield_layers*2)+visual_age*0.65
		var center := Vector2(cos(angle)*36.0, sin(angle)*16.0-18.0)
		var alpha := (0.45+0.3*shield_fraction)*(0.7+0.3*sin(angle))
		var vertices := PackedVector2Array([center+Vector2(0,-7),center+Vector2(3,0),center+Vector2(0,7),center+Vector2(-3,0)])
		draw_colored_polygon(vertices,Color(0.6,0.91,1.0,alpha))
		draw_line(vertices[0],vertices[2],Color(0.91,1,1,alpha),1.0,true)
