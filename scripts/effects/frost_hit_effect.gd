## 可复用的短促冰晶命中反馈，固定几何预算，不生成伤害或碰撞。
extends Node2D
var effect_age := 0.0
var effect_duration := 0.35
var profile := 0
var _phase := 0.0
var _radius := 28.0

func configure(position_in_world: Vector2, kind: int, phase: float) -> void:
	top_level = true
	global_position = position_in_world
	profile = kind
	_phase = phase
	effect_age = 0.0
	effect_duration = 0.5 if kind == 2 else 0.32
	_radius = 56.0 if kind == 2 else (38.0 if kind == 1 else 26.0)
	visible = true
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	effect_age += delta
	if effect_age >= effect_duration:
		deactivate()
	else:
		queue_redraw()

func deactivate() -> void:
	visible = false
	set_process(false)

func _draw() -> void:
	if not visible:
		return
	var t := clampf(effect_age / effect_duration,0.0,1.0)
	var alpha := (1.0 - t) * smoothstep(0.0,0.09,t)
	var travel := pow(t,0.5)
	var count := 16 if profile == 2 else 10
	for index: int in count:
		var axis := Vector2.from_angle(float(index)*TAU/count+_phase*0.37)
		var side := axis.orthogonal()
		var start := axis * (_radius*travel*0.65)
		var tip := start+axis*(11.0-7.0*t)
		var left := start-side*2.0
		var right := start+side*2.0
		draw_colored_polygon(PackedVector2Array([left,tip,start]),Color(0.3,0.7,0.95,alpha*0.65))
		draw_colored_polygon(PackedVector2Array([start,tip,right]),Color(0.88,0.99,1,alpha))
		if profile != 0:
			draw_line(axis*5.0, start,Color(0.75,0.96,1,alpha*0.55),1.0,true)
	draw_arc(Vector2.ZERO,_radius*travel,0,TAU,32,Color(0.72,0.95,1,alpha*0.3),1.0,true)
	draw_line(Vector2(-8,0),Vector2(8,0),Color(0.93,1,1,alpha),1.5,true)
	draw_line(Vector2(0,-8),Vector2(0,8),Color(0.93,1,1,alpha),1.5,true)
