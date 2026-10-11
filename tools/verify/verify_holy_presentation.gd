extends SceneTree
var failed:=false
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label);failed=failed or not ok
func run() -> void:
	check(ResourceLoader.exists("res://scenes/effects/holy_status_effect.tscn"),"holy status scene exists")
	check(ResourceLoader.exists("res://scripts/visual/holy_combat_presentation.gd"),"holy actual combat presentation exists")
	if failed: quit(1);return
	var scene: PackedScene=load("res://scenes/effects/holy_status_effect.tscn")
	var a: Node2D=scene.instantiate();var b: Node2D=scene.instantiate();root.add_child(a);root.add_child(b)
	a.configure_status({"status_id":"judgment","stacks":5,"duration_remaining":1.0,"host_controls_lifetime":true})
	b.configure_status({"status_id":"judgment","stacks":2,"duration_remaining":6.0})
	check(a.status_stacks==5 and b.status_stacks==2,"five real judgment stacks isolated")
	check(a._material!=b._material,"holy status uniforms independently owned")
	a._process(2.0);check(a.visible,"actual judgment host owns expiration")
	a.configure_status({"status_id":"judgment","stacks":5,"duration_remaining":1.0,"duration_paused":true,"host_controls_lifetime":true})
	a._process(2.0);check(a.remaining==1.0 and a.visible,"paused real judgment holds deadline")
	a.deactivate();a.configure_status({"status_id":"holy_shield","shield_fraction":0.2})
	check(a.profile==1 and a.visual_age==0.0,"reuse selects shield and resets age")
	var owner:=Node2D.new();root.add_child(owner)
	var bus: Node=preload("res://scripts/skills/skill_event_bus.gd").new();owner.add_child(bus)
	var view: Node=bus.get_node_or_null("HolyCombatPresentation")
	check(view!=null,"bus attaches production holy presentation")
	if view!=null:
		view._on_damage({"damage_amount":0,"element":"holy"})
		view._on_shield({"shield_amount":0,"shield_source_skill_id":"holy_attack_judgment"})
		check(view._hits.is_empty() and view._bursts.is_empty(),"zero damage and zero gained shield create no false feedback")
		for i: int in 40: view._play_burst(Vector2(i,0),2)
		check(view._bursts.size()==12,"shield confirmation pool bounded at twelve")
		view.reset_presentation()
		var hidden:=true
		for item: Node2D in view._bursts: hidden=hidden and not item.visible
		check(hidden,"run reset clears all holy bursts")
	owner.queue_free();a.queue_free();b.queue_free();await process_frame;quit(1 if failed else 0)
