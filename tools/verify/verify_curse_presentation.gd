extends SceneTree
var failed := false
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	failed=failed or not ok
func run() -> void:
	check(ResourceLoader.exists("res://scenes/effects/curse_status_effect.tscn"),"cursed procedural scene exists")
	check(ResourceLoader.exists("res://scripts/visual/curse_combat_presentation.gd"),"curse confirmed presentation exists")
	if failed: quit(1); return
	var scene: PackedScene=load("res://scenes/effects/curse_status_effect.tscn")
	var a: Node2D=scene.instantiate()
	var b: Node2D=scene.instantiate()
	root.add_child(a); root.add_child(b)
	a.configure_status({"status_id":"cursed","stacks":3,"duration_remaining":1.5})
	b.configure_status({"status_id":"cursed","stacks":1,"duration_remaining":3.0})
	check(a.status_stacks==3 and b.status_stacks==1,"real curse stack snapshots independent")
	check(a._material!=b._material,"curse materials independent")
	a._process(0.25)
	check(is_equal_approx(a.visual_age,0.25) and is_equal_approx(a.remaining,1.25),"delta advances visual age and last real deadline")
	a.deactivate(); a.configure_status({"status_id":"harvest_ready","stacks":1})
	check(is_zero_approx(a.visual_age) and a.profile==2,"reuse clears curse deadline and selects ready aura")
	var owner:=Node2D.new();root.add_child(owner)
	var bus: Node=preload("res://scripts/skills/skill_event_bus.gd").new();owner.add_child(bus)
	var view: Node=bus.get_node_or_null("CurseCombatPresentation")
	check(view!=null,"event bus attaches curse presentation")
	if view!=null:
		view._on_damage({"damage_amount":0,"source_skill_id":"curse_attack_cursing"})
		view._on_resolved({"resolved_damage":0})
		check(view._hits.is_empty() and view._bursts.is_empty(),"zero damage and failed settlement create no feedback")
		for i: int in 40: view.play_link(Vector2.ZERO,Vector2(100,i),1)
		check(view._links.size()==24,"curse chain pool bounded at twenty-four")
		var target:=Node2D.new();root.add_child(target)
		target.set_meta("death_pact",true)
		view.mark_contract(target,5.0)
		var marker: Node2D=view._contracts[0]
		check(marker.visible,"registered death pact gets mark")
		target.set_meta("death_pact",false);view._process(0.01)
		check(not marker.visible,"settled or cleared contract immediately hides mark")
		target.set_meta("death_pact",true);view.mark_contract(target,5.0);target.free();view._process(0.01)
		check(not marker.visible,"freed pact target safely clears marker")
		view.reset_presentation()
		check(view._contract_targets.is_empty(),"run reset clears contract references")
		var all_hidden:=true
		for link: Node2D in view._links: all_hidden=all_hidden and not link.visible
		check(all_hidden,"reset clears all curse links")
	owner.queue_free();a.queue_free();b.queue_free()
	await process_frame
	quit(1 if failed else 0)
