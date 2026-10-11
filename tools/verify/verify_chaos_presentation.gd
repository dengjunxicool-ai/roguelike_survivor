extends SceneTree
var failed:=false
func _init() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label);failed=failed or not ok
func run() -> void:
	check(ResourceLoader.exists("res://scenes/effects/chaos_status_effect.tscn"),"chaos status scene exists")
	check(ResourceLoader.exists("res://scripts/visual/chaos_combat_presentation.gd"),"chaos presentation exists")
	if failed: quit(1);return
	var scene: PackedScene=load("res://scenes/effects/chaos_status_effect.tscn")
	var a: Node2D=scene.instantiate();var b: Node2D=scene.instantiate();root.add_child(a);root.add_child(b)
	a.configure_status({"status_id":"instability","stacks":4,"duration_remaining":1.0,"host_controls_lifetime":true})
	b.configure_status({"status_id":"instability","stacks":1,"duration_remaining":6.0})
	check(a.status_stacks==4 and b.status_stacks==1 and a._material!=b._material,"actual instability stacks isolated")
	a._process(2.0);check(a.visible,"host controls actual expiry")
	a.configure_status({"status_id":"instability","stacks":3,"duration_remaining":1.0,"duration_paused":true,"host_controls_lifetime":true})
	a._process(2.0);check(a.remaining==1.0,"paused duration retained")
	a.deactivate();a.configure_status({"status_id":"stability","charge_fraction":1.0,"ready":true})
	check(a.profile==2 and a.visual_age==0.0,"reused state aura resets")
	var owner:=Node2D.new();root.add_child(owner)
	var bus: Node=load("res://scripts/skills/skill_event_bus.gd").new();owner.add_child(bus)
	var view: Node=bus.get_node_or_null("ChaosCombatPresentation")
	check(view!=null,"actual bus attaches chaos presentation")
	if view!=null:
		view._on_damage({"damage_amount":0,"source_skill_id":"chaos_attack_chaotic"})
		view._on_damage({"damage_amount":100,"element":"arcane","source_skill_id":"curse_cast_spirit_orb"})
		check(view._hits.is_empty(),"no zero or unrelated arcane false hit")
		for i: int in 40: view.play_replay(Vector2(i,0));view.play_swap(Vector2.ZERO,Vector2(i,20))
		check(view._bursts.size()==12 and view._links.size()==12,"bounded feedback and actual swap pools")
		view.reset_presentation()
		var hidden:=true
		for item: Node2D in view._bursts+view._links: hidden=hidden and not item.visible
		check(hidden,"run reset clears feedback")
	owner.queue_free();a.queue_free();b.queue_free();await process_frame;quit(1 if failed else 0)
