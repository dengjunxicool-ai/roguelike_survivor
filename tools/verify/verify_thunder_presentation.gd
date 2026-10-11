extends SceneTree
class ThunderManager:
	extends Node
	func has_skill(id: StringName) -> bool: return id==&"thunder_attack_thundering"
var failed := false
func _init() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	failed = failed or not ok
func run() -> void:
	check(ResourceLoader.exists("res://scenes/effects/thunder_status_effect.tscn"),"conductive procedural scene exists")
	check(ResourceLoader.exists("res://scripts/visual/thunder_combat_presentation.gd"),"thunder confirmed presentation exists")
	if failed:
		quit(1)
		return
	var scene: PackedScene = load("res://scenes/effects/thunder_status_effect.tscn")
	var a: Node2D = scene.instantiate()
	var b: Node2D = scene.instantiate()
	root.add_child(a)
	root.add_child(b)
	a.configure_status({"status_id":"conductive","stacks":4})
	b.configure_status({"status_id":"conductive","stacks":1})
	check(a.status_stacks==4 and b.status_stacks==1,"real stack snapshots remain independent")
	check(a._material!=b._material,"status shader materials independent")
	a._process(0.25)
	check(is_equal_approx(a.visual_age,0.25),"status delta controls age")
	a.deactivate()
	a.configure_status({"status_id":"static_charge","stacks":2})
	check(is_zero_approx(a.visual_age) and a.visible,"pooled aura clears stale age")
	var count:=a.get_child_count()
	for i: int in 200: a.configure_status({"stacks":i%5+1})
	check(a.get_child_count()==count,"status reconfiguration keeps node budget fixed")
	var bus: Node = preload("res://scripts/skills/skill_event_bus.gd").new()
	var owner:=Node2D.new()
	root.add_child(owner)
	owner.add_child(bus)
	var view: Node = bus.get_node_or_null("ThunderCombatPresentation")
	check(view!=null,"event bus attaches thunder presentation")
	if view!=null:
		view._on_damage({"damage_amount":0,"element":"lightning"})
		check(view._hits.is_empty(),"rejected damage does not manufacture hit feedback")
		var thunder_manager:=ThunderManager.new()
		root.add_child(thunder_manager)
		view._on_damage({"damage_amount":5,"damage_origin":"primary_attack","element":"neutral","position":Vector2.ZERO,"skill_manager":thunder_manager})
		check(view._hits.size()==1 and view._hits[0].visible,"owned thundering primary attack shows electric hit without changing damage element")
		thunder_manager.queue_free()
		for i: int in 80: view.play_chain(Vector2.ZERO,Vector2(100,i),float(i))
		check(view._arcs.size()<=24,"chain presentation has bounded pool")
		view.reset_presentation()
		var hidden:=true
		for arc: Node2D in view._arcs: hidden=hidden and not arc.visible
		check(hidden,"run reset clears chain feedback")
		var target:=Node2D.new()
		root.add_child(target)
		var projectile:=preload("res://scripts/combat/projectile.gd").new()
		root.add_child(projectile)
		projectile.visible=true
		view.mark_crow_target(target,projectile)
		var marker: Node2D=view._markers[0]
		check(marker.visible,"actual live projectile exposes crow target mark")
		target.global_position=Vector2(31,47)
		view._process(0.01)
		check(marker.global_position==target.global_position,"target mark follows actual target")
		projectile.spawn_generation+=1
		view._process(0.01)
		check(not marker.visible,"projectile generation change clears stale mark")
		view.mark_crow_target(target,projectile)
		projectile.visible=false
		view._process(0.01)
		check(not marker.visible,"returned projectile clears target mark")
		projectile.visible=true
		view.mark_crow_target(target,projectile)
		target.free()
		view._process(0.01)
		check(not marker.visible,"freed target clears mark without stale access")
		view.reset_presentation()
		check(view._marker_targets.is_empty(),"run reset clears marker weak references")
		var hit:=preload("res://scripts/effects/thunder_hit_effect.gd").new()
		root.add_child(hit)
		hit.configure(Vector2.ZERO,38.0,1.0,true)
		check(hit._strike.visible and not hit.get_child(0).visible,"crow confirmed hit selects pure sky strike")
		hit.deactivate()
		hit.configure(Vector2.ZERO,27.0,2.0,false)
		check(not hit._strike.visible and hit.get_child(0).visible,"pooled ordinary hit clears old sky strike")
		hit.queue_free()
		projectile.queue_free()
	owner.queue_free()
	a.queue_free()
	b.queue_free()
	await process_frame
	quit(1 if failed else 0)
